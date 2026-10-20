import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

export function openDatabase(directory) {
  mkdirSync(directory, { recursive: true, mode: 0o700 });
  const db = new DatabaseSync(resolve(directory, 'uchet.sqlite'));
  db.exec(`PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;
    CREATE TABLE IF NOT EXISTS schema_versions(version INTEGER PRIMARY KEY);
    CREATE TABLE IF NOT EXISTS users(
      id TEXT PRIMARY KEY, login TEXT NOT NULL UNIQUE, password TEXT NOT NULL,
      name TEXT NOT NULL, created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS sessions(
      token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id),
      expires_at INTEGER NOT NULL);
    CREATE INDEX IF NOT EXISTS sessions_user ON sessions(user_id);
    CREATE TABLE IF NOT EXISTS companies(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, currency TEXT NOT NULL,
      created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS memberships(
      company_id TEXT NOT NULL REFERENCES companies(id),
      user_id TEXT NOT NULL REFERENCES users(id),
      role TEXT NOT NULL CHECK(role IN ('owner','member')),
      permissions TEXT NOT NULL DEFAULT '[]', PRIMARY KEY(company_id,user_id));
    CREATE TABLE IF NOT EXISTS documents(
      company_id TEXT NOT NULL REFERENCES companies(id), kind TEXT NOT NULL,
      id TEXT NOT NULL, data TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      PRIMARY KEY(company_id,kind,id));
    CREATE TABLE IF NOT EXISTS batches(
      id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
      product_id TEXT NOT NULL, warehouse_id TEXT NOT NULL, scope TEXT NOT NULL,
      quantity INTEGER NOT NULL CHECK(quantity>=0),
      reserved INTEGER NOT NULL DEFAULT 0 CHECK(reserved>=0 AND reserved<=quantity),
      unit_cost INTEGER NOT NULL CHECK(unit_cost>=0), created_at TEXT NOT NULL);
    CREATE INDEX IF NOT EXISTS batches_stock ON batches(company_id,product_id,warehouse_id,scope);
    CREATE TABLE IF NOT EXISTS orders(
      id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
      status TEXT NOT NULL, data TEXT NOT NULL, created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS reservations(
      order_id TEXT NOT NULL REFERENCES orders(id), batch_id TEXT NOT NULL REFERENCES batches(id),
      quantity INTEGER NOT NULL CHECK(quantity>0), PRIMARY KEY(order_id,batch_id));
    CREATE TABLE IF NOT EXISTS journal(
      id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
      scope TEXT NOT NULL, currency TEXT NOT NULL, description TEXT NOT NULL,
      lines TEXT NOT NULL, created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS payments(
      id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
      order_id TEXT NOT NULL REFERENCES orders(id), amount INTEGER NOT NULL CHECK(amount>0),
      created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS files(
      id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
      name TEXT NOT NULL, mime TEXT NOT NULL, size INTEGER NOT NULL, created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS audit(
      sequence INTEGER PRIMARY KEY AUTOINCREMENT, company_id TEXT NOT NULL,
      actor_id TEXT NOT NULL, action TEXT NOT NULL, resource_id TEXT NOT NULL,
      created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS idempotency(
      company_id TEXT NOT NULL, actor_id TEXT NOT NULL, key TEXT NOT NULL,
      fingerprint TEXT NOT NULL, response TEXT NOT NULL,
      PRIMARY KEY(company_id,actor_id,key));
    INSERT OR IGNORE INTO schema_versions VALUES(1);`);
  return db;
}

// All callbacks are synchronous: no network or filesystem waits inside a transaction.
export function transaction(db, fn) {
  db.exec('BEGIN IMMEDIATE');
  try { const result = fn(); db.exec('COMMIT'); return result; }
  catch (error) { db.exec('ROLLBACK'); throw error; }
}
