import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";

// Docker secrets stay in files rather than image layers or command arguments.
if (process.env.DATABASE_URL_FILE) {
  try {
    const value = (
      await readFile(process.env.DATABASE_URL_FILE, "utf8")
    ).trim();
    const url = new URL(value);
    if (
      !["postgresql:", "postgres:"].includes(url.protocol) ||
      !url.hostname ||
      !url.pathname.slice(1)
    )
      throw Error();
    process.env.DATABASE_URL = value;
  } catch {
    console.error("Database secret is missing, unreadable or invalid.");
    process.exit(1);
  }
}
if (!process.env.DATABASE_URL) {
  console.error("DATABASE_URL_FILE or DATABASE_URL is required.");
  process.exit(1);
}
const selectedCommand = process.argv[2];
if (
  (selectedCommand !== "src/issue-recovery.js" && process.argv.length !== 3) ||
  ![
    "src/main.js",
    "src/migrate.js",
    "src/provision-owner.js",
    "src/issue-recovery.js",
  ].includes(selectedCommand)
) {
  console.error("Unsupported container command.");
  process.exit(1);
}
const script = resolve(selectedCommand);
process.argv = [process.argv[0], script, ...process.argv.slice(3)];
await import(pathToFileURL(script).href);
