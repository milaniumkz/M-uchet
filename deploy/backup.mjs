import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from "node:crypto";
import { createReadStream, createWriteStream } from "node:fs";
import {
  readFile,
  writeFile,
  appendFile,
  mkdir,
  mkdtemp,
  rename,
  rm,
  lstat,
  open,
} from "node:fs/promises";
import { pipeline } from "node:stream/promises";
import { Readable } from "node:stream";
import { spawn } from "node:child_process";
import { resolve, join, basename } from "node:path";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";
const root = resolve(new URL("..", import.meta.url).pathname),
  magic = Buffer.from("MUCHETB1");
async function keyFromFile(file) {
  const metadata = await lstat(file);
  if (!metadata.isFile() || (metadata.mode & 0o077) !== 0)
    throw Error("The backup key must be a private regular file (0400 or0600).");
  const key = await readFile(file);
  if (key.length !== 32) {
    key.fill(0);
    throw Error("A binary32-byte backup key is required.");
  }
  return key;
}
async function sha256(file) {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(file)) hash.update(chunk);
  return hash.digest("hex");
}
async function encryptStream(source, file, key) {
  const header = Buffer.concat([magic, randomBytes(12)]),
    cipher = createCipheriv("aes-256-gcm", key, header.subarray(8));
  cipher.setAAD(header);
  const output = createWriteStream(file, { flags: "wx", mode: 0o600 });
  output.write(header);
  await pipeline(source, cipher, output);
  await appendFile(file, cipher.getAuthTag());
  return {
    file: basename(file),
    sha256: await sha256(file),
    cipher: "AES-256-GCM",
    format: 1,
  };
}
async function decryptStream(source, target, key) {
  const metadata = await lstat(source);
  if (!metadata.isFile() || metadata.size < 36)
    throw Error("Invalid encrypted backup file.");
  const handle = await open(source, "r"),
    header = Buffer.alloc(20),
    tag = Buffer.alloc(16);
  try {
    await handle.read(header, 0, 20, 0);
    await handle.read(tag, 0, 16, metadata.size - 16);
  } finally {
    await handle.close();
  }
  if (!header.subarray(0, 8).equals(magic))
    throw Error("Unknown backup format.");
  const decipher = createDecipheriv("aes-256-gcm", key, header.subarray(8));
  decipher.setAAD(header);
  decipher.setAuthTag(tag);
  const input =
    metadata.size === 36
      ? Readable.from([])
      : createReadStream(source, { start: 20, end: metadata.size - 17 });
  await pipeline(
    input,
    decipher,
    createWriteStream(target, { flags: "wx", mode: 0o600 }),
  );
}
export function composeRunner({
  env = process.env,
  project = env.MUCHET_COMPOSE_PROJECT ?? "muchet",
} = {}) {
  if (!/^[a-z0-9][a-z0-9_-]*$/.test(project))
    throw Error("Invalid Compose project name.");
  const start = (args) =>
    spawn(
      "docker",
      ["compose", "-f", "deploy/compose.yaml", "-p", project, ...args],
      { cwd: root, env, stdio: ["ignore", "pipe", "pipe"] },
    );
  const settled = (child) => {
    child.stderr.resume();
    return new Promise((done, reject) => {
      child.once("error", reject);
      child.once("exit", (code) =>
        code === 0 ? done() : reject(Error("Compose backup command failed.")),
      );
    });
  };
  return {
    async output(args) {
      const child = start(args),
        completion = settled(child),
        chunks = [];
      child.stdout.on("data", (c) => chunks.push(c));
      await completion;
      return Buffer.concat(chunks).toString("utf8");
    },
    async encrypted(args, file, key) {
      const child = start(args),
        completion = settled(child);
      const encrypted = encryptStream(child.stdout, file, key);
      try {
        const [result] = await Promise.all([encrypted, completion]);
        return result;
      } catch (error) {
        child.kill("SIGTERM");
        await Promise.allSettled([encrypted, completion]);
        throw error;
      }
    },
  };
}
export async function createBackup({
  directory,
  keyFile,
  runner = composeRunner(),
}) {
  const key = await keyFromFile(keyFile);
  let temporary,
    stopped = false,
    result;
  try {
    await mkdir(directory, { recursive: true, mode: 0o700 });
    temporary = await mkdtemp(join(resolve(directory), ".muchet-partial-"));
    if (
      !(
        await runner.output(["ps", "--status", "running", "--quiet", "api"])
      ).trim()
    )
      throw Error(
        "A running verified API is required before taking a maintenance backup.",
      );
    const sourceImages = JSON.parse(
      await runner.output(["images", "--format", "json", "api"]),
    );
    stopped = true;
    await runner.output(["stop", "api"]);
    const schemaVersion = Number(
      (
        await runner.output([
          "exec",
          "-T",
          "db",
          "psql",
          "-U",
          "muchet",
          "-d",
          "muchet",
          "-At",
          "-c",
          "SELECT MAX(version) FROM public.schema_versions",
        ])
      ).trim(),
    );
    if (!Number.isSafeInteger(schemaVersion) || schemaVersion < 1)
      throw Error("Cannot verify backup database schema.");
    const database = await runner.encrypted(
      [
        "exec",
        "-T",
        "db",
        "pg_dump",
        "-U",
        "muchet",
        "-d",
        "muchet",
        "--format=custom",
        "--no-owner",
        "--no-acl",
      ],
      join(temporary, "database.dump.enc"),
      key,
    );
    const uploads = await runner.encrypted(
      [
        "run",
        "--rm",
        "--no-deps",
        "-T",
        "--entrypoint",
        "tar",
        "api",
        "-czf",
        "-",
        "-C",
        "/app/data",
        ".",
      ],
      join(temporary, "data.tar.gz.enc"),
      key,
    );
    const manifest = {
      format: 1,
      schemaVersion,
      sourceImages,
      createdAt: new Date().toISOString(),
      database: "PostgreSQL17 custom dump",
      consistency:
        "API stopped throughout database and data snapshot; other writers must be excluded by the operator",
      files: { database, uploads },
    };
    await writeFile(
      join(temporary, "manifest.json"),
      JSON.stringify(manifest, null, 2) + "\n",
      { flag: "wx", mode: 0o600 },
    );
    result = join(
      resolve(directory),
      "muchet-" +
        Date.now() +
        "-" +
        basename(temporary).replace(".muchet-partial-", ""),
    );
    await rename(temporary, result);
    temporary = null;
  } finally {
    key.fill(0);
    if (temporary) await rm(temporary, { recursive: true, force: true });
    if (stopped)
      await runner.output([
        "up",
        "-d",
        "--wait",
        "--wait-timeout",
        "90",
        "api",
      ]);
  }
  return result;
}
export async function decryptBackup({ backup, directory, keyFile }) {
  const key = await keyFromFile(keyFile);
  let temporary;
  try {
    const manifest = JSON.parse(
      await readFile(join(backup, "manifest.json"), "utf8"),
    );
    if (manifest.format !== 1) throw Error("Unknown backup manifest format.");
    const expected = {
      database: ["database.dump.enc", "database.dump"],
      uploads: ["data.tar.gz.enc", "data.tar.gz"],
    };
    await mkdir(directory, { recursive: true, mode: 0o700 });
    temporary = await mkdtemp(join(resolve(directory), ".muchet-decrypt-"));
    for (const [kind, [encrypted, plain]] of Object.entries(expected)) {
      const entry = manifest.files?.[kind];
      if (
        entry?.file !== encrypted ||
        entry.cipher !== "AES-256-GCM" ||
        entry.format !== 1
      )
        throw Error("Invalid backup manifest entry.");
      const source = join(backup, encrypted);
      if ((await sha256(source)) !== entry.sha256)
        throw Error("Encrypted backup checksum mismatch.");
      await decryptStream(source, join(temporary, plain), key);
    }
    await writeFile(
      join(temporary, "manifest.json"),
      JSON.stringify(manifest, null, 2) + "\n",
      { flag: "wx", mode: 0o600 },
    );
    const result = join(
      resolve(directory),
      "muchet-decrypted-" +
        Date.now() +
        "-" +
        basename(temporary).replace(".muchet-decrypt-", ""),
    );
    await rename(temporary, result);
    temporary = null;
    return result;
  } finally {
    key.fill(0);
    if (temporary) await rm(temporary, { recursive: true, force: true });
  }
}
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  try {
    const { values, positionals } = parseArgs({
      allowPositionals: true,
      options: {
        directory: { type: "string" },
        "key-file": { type: "string" },
        backup: { type: "string" },
      },
    });
    if (!values.directory || !values["key-file"] || positionals.length !== 1)
      throw Error(
        "Usage: create|decrypt --directory PATH --key-file PATH [--backup PATH]",
      );
    const result =
      positionals[0] === "create"
        ? await createBackup({
            directory: values.directory,
            keyFile: values["key-file"],
          })
        : positionals[0] === "decrypt" && values.backup
          ? await decryptBackup({
              backup: values.backup,
              directory: values.directory,
              keyFile: values["key-file"],
            })
          : null;
    if (!result) throw Error("Unknown backup command.");
    console.log("Backup operation completed: " + result);
  } catch (error) {
    console.error("Backup operation failed: " + error.message);
    process.exitCode = 1;
  }
}
