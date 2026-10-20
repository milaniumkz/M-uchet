import { spawn } from "node:child_process";
import { access, mkdir } from "node:fs/promises";
import { resolve } from "node:path";
const root = resolve(new URL("..", import.meta.url).pathname);
try {
  await access(resolve(root, "build/web/main.dart.js"));
} catch {
  throw Error("Build the current web client first: make build-web");
}
const buildx = process.env.BUILDX_CONFIG ?? resolve(root, ".runtime/buildx");
await mkdir(buildx, { recursive: true });
const args = [
  "build",
  "-f",
  "deploy/Dockerfile",
  "-t",
  process.argv[2] ?? "muchet:local-check",
];
if (process.env.CODEX_PROXY_CERT) {
  await access(process.env.CODEX_PROXY_CERT);
  args.push("--secret", "id=proxy_ca,src=" + process.env.CODEX_PROXY_CERT);
}
args.push(".");
const child = spawn("docker", args, {
  cwd: root,
  env: { ...process.env, BUILDX_CONFIG: buildx },
  stdio: "inherit",
});
const code = await new Promise((done, reject) => {
  child.once("error", reject);
  child.once("exit", done);
});
process.exitCode = code ?? 1;
