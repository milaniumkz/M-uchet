import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, readdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import pg from "pg";
import { createApp } from "../src/app.js";
import { hashPassword } from "../src/security.js";

test("schema 21 debts migrate renamed journal sources without changing cash and remain editable", async (t) => {
  const schema = "test_" + randomUUID().replaceAll("-", ""),
    dir = await mkdtemp(join(tmpdir(), "muchet-debt-migration-"));
  const pool = new pg.Pool({
    connectionString: process.env.DATABASE_URL,
    options: `-c search_path=${schema}`,
  });
  let app;
  t.after(async () => {
    await app?.close();
    await pool.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
    await pool.end();
    await rm(dir, { recursive: true, force: true });
  });
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(`CREATE SCHEMA "${schema}"`);
    const directory = new URL("../migrations/", import.meta.url);
    for (const file of (await readdir(directory))
      .filter((x) => /^\d+.*\.sql$/.test(x) && x < "021_")
      .sort())
      await client.query(await readFile(new URL(file, directory), "utf8"));
    const now = "2026-01-10T12:00:00.000Z";
    await client.query(
      "INSERT INTO users(id,login,password,name,created_at) VALUES($1,$2,$3,$4,$5)",
      [
        "owner",
        "synthetic-migration@example.test",
        await hashPassword("SYNTHETIC migration password"),
        "SYNTHETIC OWNER",
        now,
      ],
    );
    await client.query(
      "INSERT INTO companies(id,name,currency,created_at) VALUES('firm','SYNTHETIC MIGRATION','KZT',$1)",
      [now],
    );
    await client.query(
      "INSERT INTO memberships(company_id,user_id,role) VALUES('firm','owner','owner')",
    );
    await client.query(
      "INSERT INTO documents(company_id,kind,id,data,created_at,updated_at) VALUES('firm','clients','client','{\"name\":\"SYNTHETIC LEGACY CLIENT\"}',$1,$1)",
      [now],
    );
    await client.query(
      "INSERT INTO wallets(id,company_id,name,scope,balance) VALUES('cash','firm','SYNTHETIC CASH','ACCOUNTING',300)",
    );
    await client.query(
      "INSERT INTO debts(id,company_id,type,counterparty_id,total,remaining,scope,created_at) VALUES('debt','firm','AR','client',500,200,'ACCOUNTING',$1),('unlinked','firm','AR','client',100,100,'ACCOUNTING',$1)",
      [now],
    );
    await client.query(
      "INSERT INTO debt_payments(id,company_id,debt_id,wallet_id,amount,created_at) VALUES('payment','firm','debt','cash',300,$1)",
      [now],
    );
    for (const [id, description, date, lines] of [
      [
        "opening",
        "Opening debt debt",
        "2026-01-10",
        [
          { account: "receivables", debit: 500, credit: 0 },
          { account: "opening_balances", debit: 0, credit: 500 },
        ],
      ],
      [
        "receipt",
        "Debt payment payment",
        "2026-01-05",
        [
          { account: "wallet:cash", debit: 300, credit: 0 },
          { account: "receivables", debit: 0, credit: 300 },
        ],
      ],
    ]) {
      await client.query(
        "INSERT INTO journal(id,company_id,scope,currency,description,lines,created_at,business_date) VALUES($1,'firm','ACCOUNTING','KZT',$2,$3,$4,$5)",
        [id, description, JSON.stringify(lines), now, date],
      );
      for (const [i, line] of lines.entries())
        await client.query(
          "INSERT INTO journal_lines(entry_id,position,account,debit,credit) VALUES($1,$2,$3,$4,$5)",
          [id, i, line.account, line.debit, line.credit],
        );
      await client.query(
        "UPDATE journal SET description='Manual: renamed source' WHERE id=$1",
        [id],
      );
    }
    await client.query(
      "INSERT INTO wallet_entries(id,company_id,wallet_id,amount,kind,reference_id,created_at) VALUES('receipt-entry','firm','cash',300,'DEBT_PAYMENT','payment',$1)",
      [now],
    );
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
  app = await createApp({ schema, dataDir: dir });
  const logged = await app.inject({
    method: "POST",
    url: "/v1/auth/login",
    payload: {
      login: "synthetic-migration@example.test",
      password: "SYNTHETIC migration password",
    },
  });
  assert.equal(logged.statusCode, 200);
  const token = logged.json().token;
  const call = async (method, path, payload) => {
    const r = await app.inject({
      method,
      url: "/v1/companies/firm" + path,
      payload,
      headers: {
        authorization: "Bearer " + token,
        "idempotency-key": randomUUID(),
      },
    });
    return { status: r.statusCode, body: r.json() };
  };
  let debt = (await call("GET", "/debts/debt")).body;
  assert.equal(debt.sourceComplete, true);
  assert.equal(debt.business_date, "2026-01-10");
  assert.equal(debt.payments[0].business_date, "2026-01-05");
  assert.equal(debt.payments[0].journal_id, "receipt");
  assert.equal(
    (
      await pool.query(
        "SELECT journal_id FROM wallet_entries WHERE id='receipt-entry'",
      )
    ).rows[0].journal_id,
    "receipt",
  );
  assert.equal(
    (
      await call("POST", "/accounting/journal/receipt/reverse", {
        reason: "Attempt bypass",
      })
    ).status,
    409,
  );
  const corrected = await call("PUT", "/debts/debt", {
    version: debt.version,
    type: "AR",
    counterpartyId: "client",
    amount: 200,
    businessDate: "2026-02-10",
  });
  assert.equal(corrected.status, 200, JSON.stringify(corrected.body));
  assert.equal(corrected.body.advance, 100);
  assert.equal((await call("GET", "/wallets")).body.items[0].balance, 300);
  debt = (await call("GET", "/debts/unlinked")).body;
  assert.equal(debt.sourceComplete, false);
  assert.equal(
    (
      await call("PUT", "/debts/unlinked", {
        version: 1,
        type: "AR",
        counterpartyId: "client",
        amount: 50,
      })
    ).status,
    422,
  );
});
