import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";
import assert from "node:assert/strict";
import { createApp } from "../src/app.js";
import { issueRecoveryToken } from "../src/recovery.js";
if (process.env.APP_ENV !== "test") throw Error("APP_ENV=test required");
const root = resolve(new URL("../..", import.meta.url).pathname);
const available = [
  "test_live/rest_repository_test.dart",
  "test_live/project_workspace_test.dart",
  "test_live/commercial_workspace_test.dart",
  "test_live/refund_workspace_test.dart",
  "test_live/purchase_workspace_test.dart",
  "test_live/purchase_returns_test.dart",
  "test_live/bank_workspace_test.dart",
  "test_live/ledger_workspace_test.dart",
  "test_live/inventory_workspace_test.dart",
  "test_live/recovery_dialog_test.dart",
  "test_live/assets_workspace_test.dart",
  "test_live/employees_workspace_test.dart",
  "test_live/access_workspace_test.dart",
  "test_live/cash_workspace_test.dart",
  "test_live/counterparty_workspace_test.dart",
  "test_live/account_dialog_test.dart",
  "test_live/goods_workspace_test.dart",
  "test_live/payroll_workspace_test.dart",
  "test_live/tax_calendar_workspace_test.dart",
  "test_live/company_search_test.dart",
  "test_live/debts_workspace_test.dart",
  "test_live/home_workspace_test.dart",
  "test_live/stock_counts_workspace_test.dart",
];
const requested = process.argv.slice(2);
if (requested.some((file) => !available.includes(file)))
  throw Error("Unknown live test selection");
const files = requested.length ? requested : available;
const failed = [];
for (const file of files) {
  const schema = "test_" + randomUUID().replaceAll("-", ""),
    directory = await mkdtemp(join(tmpdir(), "muchet-dart-"));
  let app;
  try {
    app = await createApp({
      schema,
      dataDir: join(directory, "data"),
      allowRegistration: true,
    });
    const login = "synthetic-dart@example.test",
      password = randomUUID();
    const registered = await app.inject({
      method: "POST",
      url: "/v1/auth/register",
      payload: { login, password, name: "SYNTHETIC DART USER" },
    });
    assert.equal(registered.statusCode, 201);
    const session = (
      await app.inject({
        method: "POST",
        url: "/v1/auth/login",
        payload: { login, password },
      })
    ).json();
    const company = await app.inject({
      method: "POST",
      url: "/v1/companies",
      payload: { name: "SYNTHETIC DART COMPANY", currency: "KZT" },
      headers: { authorization: "Bearer " + session.token },
    });
    assert.equal(company.statusCode, 201);
    const origin = await app.listen({ host: "127.0.0.1", port: 0 }),
      fixture = join(directory, "fixture.json");
    const recoveryLogin = "synthetic-recovery@example.test",
      recoveryNextPassword = randomUUID();
    const recoveryUser = await app.inject({
      method: "POST",
      url: "/v1/auth/register",
      payload: {
        login: recoveryLogin,
        password: randomUUID(),
        name: "SYNTHETIC RECOVERY USER",
      },
    });
    assert.equal(recoveryUser.statusCode, 201);
    const recovery = await issueRecoveryToken(app.db, recoveryLogin);
    await writeFile(
      fixture,
      JSON.stringify({
        origin,
        login,
        password,
        recoveryLogin,
        recoveryNextPassword,
        recoveryToken: recovery.token,
      }),
      { mode: 0o600 },
    );
    console.log(`Live scenario: ${file}`);
    const child = spawn(
      resolve(root, "scripts/flutter.sh"),
      [
        "test",
        "--no-pub",
        file,
        "--timeout=2m",
        "--concurrency=1",
        "--reporter",
        "expanded",
      ],
      {
        cwd: root,
        env: { ...process.env, MUCHET_TEST_FIXTURE: fixture },
        stdio: ["ignore", "pipe", "inherit"],
        detached: process.platform !== "win32",
      },
    );
    let tail = "",
      timedOut = false,
      forceStop;
    child.stdout.on("data", (chunk) => {
      process.stdout.write(chunk);
      tail = (tail + chunk.toString("utf8")).slice(-65536);
    });
    const stop = (signal) => {
      try {
        if (process.platform === "win32") child.kill(signal);
        else process.kill(-child.pid, signal);
      } catch (error) {
        if (error.code !== "ESRCH") throw error;
      }
    };
    const watchdog = setTimeout(() => {
      timedOut = true;
      stop("SIGINT");
      forceStop = setTimeout(() => stop("SIGKILL"), 5000);
      forceStop.unref();
    }, 180000);
    watchdog.unref();
    let code;
    try {
      code = await new Promise((done, reject) => {
        child.once("error", reject);
        child.once("exit", done);
      });
    } finally {
      clearTimeout(watchdog);
      if (forceStop) clearTimeout(forceStop);
    }
    // Flutter can exit0 after an interrupted test. Require its completed result.
    if (code !== 0 || timedOut || !tail.includes("All tests passed!"))
      failed.push(file);
  } catch (error) {
    failed.push(file);
    console.error(error.message);
  } finally {
    if (app) {
      try {
        await app.db.exec(`DROP SCHEMA "${schema}" CASCADE`);
      } finally {
        await app.close();
      }
    }
    await rm(directory, { recursive: true, force: true });
  }
}
console.log(
  JSON.stringify({
    liveScenarios: files.length,
    passed: files.length - failed.length,
    failed,
  }),
);
if (failed.length) process.exitCode = 1;
