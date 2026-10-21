import { createBackup, decryptBackup, composeRunner } from "./backup.mjs";
import { spawn } from "node:child_process";
import { randomBytes, randomUUID } from "node:crypto";
import {
  mkdtemp,
  writeFile,
  readFile,
  readdir,
  cp,
  rm,
} from "node:fs/promises";
import { resolve, join } from "node:path";
import assert from "node:assert/strict";
const root = resolve(new URL("..", import.meta.url).pathname);
const directory = await mkdtemp(join(root, ".runtime/container-check-"));
const project = "muchet-check-" + randomBytes(5).toString("hex");
const databasePassword = randomBytes(32).toString("hex");
const adminPassword = randomBytes(32).toString("hex");
await writeFile(join(directory, "admin-password"), adminPassword, {
  mode: 0o400,
});
await writeFile(join(directory, "database-password"), databasePassword, {
  mode: 0o400,
});
await writeFile(
  join(directory, "database-url"),
  `postgresql://muchet:${databasePassword}@db:5432/muchet`,
  { mode: 0o400 },
);
const env = {
  ...process.env,
  MUCHET_IMAGE: process.argv[2] ?? "muchet:local-check",
  MUCHET_DB_ADMIN_PASSWORD_FILE: join(directory, "admin-password"),
  MUCHET_DB_PASSWORD_FILE: join(directory, "database-password"),
  MUCHET_DATABASE_URL_FILE: join(directory, "database-url"),
  MUCHET_PORT: "0",
};
async function compose(args, input) {
  const child = spawn(
    "docker",
    ["compose", "-f", "deploy/compose.yaml", "-p", project, ...args],
    { cwd: root, env, stdio: ["pipe", "pipe", "pipe"] },
  );
  const chunks = [],
    errors = [];
  child.stdout.on("data", (chunk) => chunks.push(chunk));
  child.stderr.on("data", (chunk) => errors.push(chunk));
  child.stdin.on("error", () => {});
  child.stdin.end(input ?? "");
  const code = await new Promise((done, reject) => {
    child.once("error", reject);
    child.once("exit", done);
  });
  if (code !== 0)
    throw Error(
      `Isolated container command failed: ${args[0]} (${code}). ${Buffer.concat(errors).toString("utf8").replaceAll(databasePassword, "[REDACTED]").replaceAll(adminPassword, "[REDACTED]").slice(-2000)}`,
    );
  return Buffer.concat(chunks).toString("utf8");
}
let started = false;
try {
  started = true;
  await compose(["up", "-d", "--wait", "--wait-timeout", "90"]);
  const port = (await compose(["port", "api", "8080"])).trim();
  assert.match(port, /^127\.0\.0\.1:\d+$/);
  let origin = "http://" + port;
  const credentials = {
    login: "synthetic-container@example.test",
    name: "SYNTHETIC CONTAINER OWNER",
    password: randomBytes(32).toString("base64url"),
  };
  await compose(
    ["run", "--rm", "--no-deps", "-T", "api", "src/provision-owner.js"],
    JSON.stringify(credentials),
  );
  let token;
  async function request(method, path, body, expected = 200) {
    const response = await fetch(origin + path, {
      method,
      headers: {
        ...(token ? { authorization: "Bearer " + token } : {}),
        ...(body ? { "content-type": "application/json" } : {}),
        "idempotency-key": randomUUID(),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    assert.equal(response.status, expected, `${method} ${path}`);
    return response.json();
  }
  assert.equal((await request("GET", "/health")).schemaVersion, 24);
  assert.equal((await fetch(origin + "/")).status, 200);
  assert.ok([403, 404].includes((await fetch(origin + "/.env")).status));
  await request(
    "POST",
    "/v1/auth/register",
    { login: "outsider", password: "SYNTHETIC PASSWORD", name: "Outsider" },
    403,
  );
  token = (await request("POST", "/v1/auth/login", credentials)).token;
  const company = await request(
    "POST",
    "/v1/companies",
    { name: "SYNTHETIC CONTAINER FIRM", currency: "KZT" },
    201,
  );
  const base = "/v1/companies/" + company.id;
  const wallet = await request("POST", base + "/wallets", {
    name: "SYNTHETIC CONTAINER BANK",
  });
  await request("POST", base + `/wallets/${wallet.id}/transactions`, {
    type: "CAPITAL",
    amount: 1234567,
    description: "SYNTHETIC FUNDS",
  });
  const client = await request("POST", base + "/resources/clients", {
    data: { name: "SYNTHETIC CONTAINER CLIENT" },
  });
  const debt = await request("POST", base + "/debts", {
    type: "AR",
    counterpartyId: client.id,
    amount: 500,
    businessDate: "2026-01-10",
  });
  await request("POST", base + `/debts/${debt.id}/settlements`, {
    walletId: wallet.id,
    amount: 300,
    businessDate: "2026-01-05",
  });
  const currentDebt = await request("GET", base + `/debts/${debt.id}`);
  await request("PUT", base + `/debts/${debt.id}`, {
    version: currentDebt.version,
    type: "AR",
    counterpartyId: client.id,
    amount: 200,
    businessDate: "2026-02-10",
  });
  const reconciliation = await request(
    "GET",
    base + `/counterparties/clients/${client.id}/statement`,
  );
  assert.equal(
    reconciliation.accounts.find((a) => a.account === "receivables").closing,
    0,
  );
  assert.equal(
    reconciliation.accounts.find((a) => a.account === "customer_advances")
      .closing,
    -100,
  );
  const bankImport = await request("POST", base + "/bank-imports", {
    walletId: wallet.id,
    csv: "date;reference;debit;credit;description\n2026-01-05;container-debt-link;0;3.00;SYNTHETIC DEBT RECEIPT",
  });
  const bankRow = (
      await request("GET", base + `/bank-imports/${bankImport.id}`)
    ).items[0],
    bankPath = base + `/bank-imports/${bankImport.id}/rows/${bankRow.id}`;
  const candidate = (await request("GET", bankPath + "/candidates")).items[0];
  await request("PUT", bankPath, {
    version: 1,
    classification: "EXISTING",
    entryId: candidate.id,
  });
  await request("POST", bankPath + "/post", { version: 2 });
  assert.equal(
    (await request("GET", base + `/bank-imports/${bankImport.id}`)).items[0]
      .reconciliation_status,
    "MATCHED",
  );
  await request("POST", bankPath + "/unmatch", {
    version: 3,
    reason: "SYNTHETIC CONTAINER RECONCILIATION CORRECTION",
  });
  const dashboard = await request("GET", base + "/dashboard");
  assert.equal(dashboard.money.cash, 1234867);
  assert.equal(dashboard.chart.at(-1).closing, 1234867);
  const task = await request("POST", base + "/tax-calendar", {
    title: "SYNTHETIC CONTAINER TASK",
    dueDate: "2026-01-26",
    status: "OPEN",
    category: "TAX",
    dueDateConfirmed: true,
    source: "SYNTHETIC CHECKED SOURCE",
  });
  const stockProduct = await request("POST", base + "/resources/nomenklatura", {
    data: { name: "SYNTHETIC CONTAINER STOCK", minimumStock: 9 },
  });
  const stockWarehouse = await request("POST", base + "/resources/warehouses", {
    data: { name: "SYNTHETIC CONTAINER WAREHOUSE" },
  });
  await request("POST", base + "/inventory/receipts", {
    productId: stockProduct.id,
    warehouseId: stockWarehouse.id,
    quantity: 10,
    unitCost: 23,
  });
  const countDraft = await request("POST", base + "/inventory/counts", {
    warehouseId: stockWarehouse.id,
    reason: "SYNTHETIC CONTAINER COUNT",
    lines: [{ productId: stockProduct.id, countedQuantity: 8 }],
  });
  const countPosted = await request(
    "POST",
    base + `/inventory/counts/${countDraft.id}/post`,
    { version: countDraft.version },
  );
  await request("PUT", base + `/inventory/counts/${countDraft.id}`, {
    version: countPosted.version,
    lines: [{ productId: stockProduct.id, countedQuantity: 7 }],
  });
  const stockSummary = await request("GET", base + "/inventory/balances");
  assert.equal(stockSummary.summary.value, 161);
  assert.equal(stockSummary.summary.low, 1);
  await request("PUT", base + "/settings", {
    version: 0,
    legalName: "SYNTHETIC REFUND FIRM",
    identifier: "000000000000",
    legalForm: "TOO",
    taxRegime: "GENERAL",
    vatRegistered: false,
  });
  const refundClient = await request("POST", base + "/resources/clients", {
    data: { name: "SYNTHETIC REFUND CLIENT" },
  });
  const refundWallet = await request("POST", base + "/wallets", {
    name: "SYNTHETIC REFUND WALLET",
  });
  const refundDoc = await request("POST", base + "/commercial-documents", {
    kind: "SALE_ACT",
    counterpartyId: refundClient.id,
    items: [
      {
        description: "SYNTHETIC REFUNDED SERVICE",
        quantity: "1",
        unitPrice: 10000,
      },
    ],
    businessDate: "2026-01-20",
  });
  const refundBase = base + `/commercial-documents/${refundDoc.id}`;
  await request("POST", refundBase + "/post", {});
  await request("POST", refundBase + "/payments", {
    walletId: refundWallet.id,
    amount: 10000,
    businessDate: "2026-01-21",
  });
  const refund = await request("POST", refundBase + "/payments", {
    kind: "REFUND",
    walletId: refundWallet.id,
    amount: 2000,
    businessDate: "2026-01-22",
  });
  const refundPath = refundBase + `/payments/${refund.id}`;
  await request("PUT", refundPath, { version: 1, amount: 3000 });
  await request("POST", refundPath + "/void", { version: 2 });
  await request("POST", refundPath + "/restore", { version: 3 });
  await request("PUT", refundPath, { version: 4, amount: 10000 });
  assert.equal((await request("GET", refundBase)).outstanding, 10000);
  assert.equal(
    (await request("GET", base + "/wallets")).items.find(
      (w) => w.id === refundWallet.id,
    ).balance,
    0,
  );
  const form = new FormData();
  form.append(
    "file",
    new Blob(["SYNTHETIC PRIVATE CONTAINER FILE"], { type: "text/plain" }),
    "synthetic.txt",
  );
  const upload = await fetch(origin + base + "/files", {
    method: "POST",
    headers: { authorization: "Bearer " + token },
    body: form,
  });
  assert.equal(upload.status, 200);
  const file = await upload.json();
  await compose(["restart", "api"]);
  await compose(["up", "-d", "--wait", "--wait-timeout", "60"]);
  const restartedPort = (await compose(["port", "api", "8080"])).trim();
  assert.match(restartedPort, /^127\.0\.0\.1:\d+$/);
  origin = "http://" + restartedPort;
  assert.equal(
    (await request("GET", base + "/wallets")).items.find(
      (w) => w.id === wallet.id,
    ).balance,
    1234867,
  );
  assert.equal(
    (await request("GET", base + "/tax-calendar")).items[0].id,
    task.id,
  );
  const downloaded = await fetch(origin + base + "/files/" + file.id, {
    headers: { authorization: "Bearer " + token },
  });
  assert.equal(downloaded.status, 200);
  assert.equal(await downloaded.text(), "SYNTHETIC PRIVATE CONTAINER FILE");
  const uid = (await compose(["exec", "-T", "api", "id", "-u"])).trim();
  assert.equal(uid, "1000");
  await compose([
    "exec",
    "-T",
    "api",
    "node",
    "-e",
    "try{require('node:fs').writeFileSync('/app/server/unexpected-write','x');process.exit(1)}catch(e){if(!['EROFS','EACCES'].includes(e.code))process.exit(2)}",
  ]);
  const role = (
    await compose([
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
      "SELECT rolsuper,rolcreatedb,rolcreaterole,rolreplication FROM pg_roles WHERE rolname='muchet'",
    ])
  ).trim();
  assert.equal(role, "f|f|f|f");
  const keyFile = join(directory, "backup-key");
  await writeFile(keyFile, randomBytes(32), { mode: 0o400 });
  const bundle = await createBackup({
    directory: join(directory, "backups"),
    keyFile,
    runner: composeRunner({ env, project }),
  });
  const wrongKey = join(directory, "wrong-key");
  await writeFile(wrongKey, randomBytes(32), { mode: 0o400 });
  await assert.rejects(
    decryptBackup({
      backup: bundle,
      directory: join(directory, "wrong-output"),
      keyFile: wrongKey,
    }),
  );
  assert.deepEqual(await readdir(join(directory, "wrong-output")), []);
  const tampered = join(directory, "tampered");
  await cp(bundle, tampered, { recursive: true });
  const corrupted = await readFile(join(tampered, "data.tar.gz.enc"));
  corrupted[21] ^= 1;
  await writeFile(join(tampered, "data.tar.gz.enc"), corrupted);
  await assert.rejects(
    decryptBackup({
      backup: tampered,
      directory: join(directory, "tampered-output"),
      keyFile,
    }),
  );
  assert.deepEqual(await readdir(join(directory, "tampered-output")), []);
  const plain = await decryptBackup({
    backup: bundle,
    directory: join(directory, "decrypted"),
    keyFile,
  });
  await compose([
    "exec",
    "-T",
    "db",
    "createdb",
    "-U",
    "postgres",
    "-O",
    "muchet",
    "restored",
  ]);
  await compose(
    [
      "exec",
      "-T",
      "db",
      "pg_restore",
      "-U",
      "muchet",
      "--no-owner",
      "--no-acl",
      "--dbname=restored",
    ],
    await readFile(join(plain, "database.dump")),
  );
  const restoredBalance = (
    await compose([
      "exec",
      "-T",
      "db",
      "psql",
      "-U",
      "muchet",
      "-d",
      "restored",
      "-At",
      "-c",
      `SELECT balance FROM public.wallets WHERE id='${wallet.id}'`,
    ])
  ).trim();
  assert.equal(restoredBalance, "1234867");
  const restoredRefund = (
    await compose([
      "exec",
      "-T",
      "db",
      "psql",
      "-U",
      "muchet",
      "-d",
      "restored",
      "-At",
      "-c",
      `SELECT kind || ':' || amount::text || ':' || version::text FROM public.commercial_payments WHERE id='${refund.id}'`,
    ])
  ).trim();
  assert.equal(restoredRefund, "REFUND:10000:5");
  const restoredRefundHistory = (
    await compose([
      "exec",
      "-T",
      "db",
      "psql",
      "-U",
      "muchet",
      "-d",
      "restored",
      "-At",
      "-c",
      `SELECT count(*) FROM public.entity_history WHERE kind='commercial_payment' AND entity_id='${refund.id}'`,
    ])
  ).trim();
  assert.equal(restoredRefundHistory, "4");
  const restoredDebt = (
    await compose([
      "exec",
      "-T",
      "db",
      "psql",
      "-U",
      "muchet",
      "-d",
      "restored",
      "-At",
      "-c",
      `SELECT total::text || ':' || remaining::text || ':' || version::text FROM public.debts WHERE id='${debt.id}'`,
    ])
  ).trim();
  assert.equal(restoredDebt, "200:0:3");
  const restoredPayment = (
    await compose([
      "exec",
      "-T",
      "db",
      "psql",
      "-U",
      "muchet",
      "-d",
      "restored",
      "-At",
      "-c",
      `SELECT amount::text || ':' || business_date::text FROM public.debt_payments WHERE debt_id='${debt.id}'`,
    ])
  ).trim();
  assert.equal(restoredPayment, "300:2026-01-05");
  const restoredCount = (
    await compose([
      "exec",
      "-T",
      "db",
      "psql",
      "-U",
      "muchet",
      "-d",
      "restored",
      "-At",
      "-c",
      `SELECT status || ':' || version::text || ':' || (data::jsonb->'lines'->0->'effect'->>'cost') FROM public.stock_counts WHERE id='${countDraft.id}'`,
    ])
  ).trim();
  assert.equal(restoredCount, "POSTED:3:69");
  const restoredStock = (
    await compose([
      "exec",
      "-T",
      "db",
      "psql",
      "-U",
      "muchet",
      "-d",
      "restored",
      "-At",
      "-c",
      `SELECT sum(quantity)::text FROM public.batches WHERE product_id='${stockProduct.id}'`,
    ])
  ).trim();
  assert.equal(restoredStock, "7");
  await compose(["exec", "-T", "api", "mkdir", "/app/data/restore-check"]);
  await compose(
    ["exec", "-T", "api", "tar", "-xzf", "-", "-C", "/app/data/restore-check"],
    await readFile(join(plain, "data.tar.gz")),
  );
  const restoredFile = await compose([
    "exec",
    "-T",
    "api",
    "node",
    "-e",
    `process.stdout.write(require('node:fs').readFileSync('/app/data/restore-check/uploads/${file.id}','utf8'))`,
  ]);
  assert.equal(restoredFile, "SYNTHETIC PRIVATE CONTAINER FILE");
  origin = "http://" + (await compose(["port", "api", "8080"])).trim();
  assert.equal(
    (await request("GET", base + "/tax-calendar")).items[0].id,
    task.id,
  );
  const realRunner = composeRunner({ env, project });
  const failingRunner = {
    ...realRunner,
    encrypted(args, file, key) {
      const broken = [...args];
      broken[broken.indexOf("-d") + 1] = "nonexistent_backup_database";
      return realRunner.encrypted(broken, file, key);
    },
  };
  await assert.rejects(
    createBackup({
      directory: join(directory, "failed-backup"),
      keyFile,
      runner: failingRunner,
    }),
  );
  assert.deepEqual(await readdir(join(directory, "failed-backup")), []);
  origin = "http://" + (await compose(["port", "api", "8080"])).trim();
  assert.equal(
    (await request("GET", base + "/wallets")).items.find(
      (w) => w.id === wallet.id,
    ).balance,
    1234867,
  );
  await compose([
    "run",
    "--rm",
    "--no-deps",
    "-T",
    "api",
    "src/issue-recovery.js",
    "--login",
    credentials.login,
    "--output",
    "/app/data/check-recovery.json",
  ]);
  const recovery = JSON.parse(
    await compose([
      "exec",
      "-T",
      "api",
      "node",
      "-e",
      "process.stdout.write(require('node:fs').readFileSync('/app/data/check-recovery.json','utf8'))",
    ]),
  );
  const nextPassword = randomBytes(32).toString("base64url");
  await request("POST", "/v1/auth/reset-password", {
    token: recovery.token,
    password: nextPassword,
  });
  await request("GET", "/v1/auth/me", null, 401);
  token = (
    await request("POST", "/v1/auth/login", {
      login: credentials.login,
      password: nextPassword,
    })
  ).token;
  assert.ok(token);
  console.log(
    "Container checks passed: private registration, offline owner, HTTP/web, exact wallet, corrected commercial refund and history, corrected opening debt, combined counterparty statement, bank unmatch, dashboard cash history, stock balances and corrected counts, calendar, upload, restart, encrypted backup/restore, wrong-key/tamper rejection and recovery after failed dump, offline recovery, restricted database role, non-root and read-only filesystem.",
  );
} catch (error) {
  try {
    console.error(
      (await compose(["logs", "--tail", "30", "api", "db"]))
        .replaceAll(databasePassword, "[REDACTED]")
        .replaceAll(adminPassword, "[REDACTED]"),
    );
  } catch {}
  throw error;
} finally {
  try {
    if (started) await compose(["down", "--volumes", "--remove-orphans"]);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}
