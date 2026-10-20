import pg from 'pg';
import { AsyncLocalStorage } from 'node:async_hooks';
import { readFile } from 'node:fs/promises';
const context = new AsyncLocalStorage();
const safeNumber = raw => {
  const value = Number(raw);
  if (!Number.isSafeInteger(value)) throw new Error('Database integer outside safe API range');
  return value;
};
pg.types.setTypeParser(20, safeNumber);
pg.types.setTypeParser(1700, safeNumber);
pg.types.setTypeParser(1082, value => value); // Calendar dates must not depend on the host timezone.

export async function openDatabase({ connectionString = process.env.DATABASE_URL, schema = 'public' } = {}) {
  if (!connectionString) throw new Error('DATABASE_URL is required (PostgreSQL)');
  if (!/^[a-z][a-z0-9_]{0,62}$/.test(schema)) throw new Error('Invalid database schema');
  const pool = new pg.Pool({ connectionString, max: 10, connectionTimeoutMillis: 5000,
    idleTimeoutMillis: 10000, options: `-c search_path=${schema} -c statement_timeout=10000` });
  const db = {
    pool, schema,
    async exec(sql) { return (context.getStore()?.db === db ? context.getStore().client : pool).query(sql); },
    prepare(sql) {
      let index = 0;
      const query = sql.replace(/\?/g, () => '$' + (++index));
      const execute = params => (context.getStore()?.db === db ? context.getStore().client : pool).query(query, params);
      return {
        async get(...params) { return (await execute(params)).rows[0]; },
        async all(...params) { return (await execute(params)).rows; },
        async run(...params) { const result = await execute(params); return { changes: result.rowCount }; },
      };
    },
    async close() { await pool.end(); },
  };
  try {
    await pool.query(`CREATE SCHEMA IF NOT EXISTS "${schema}"`);
    await transaction(db, async () => {
      await db.exec("SELECT pg_advisory_xact_lock(62700321)");
      await db.exec('CREATE TABLE IF NOT EXISTS schema_versions(version INTEGER PRIMARY KEY)');
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=2').get()) {
        await db.exec(await readFile(new URL('../migrations/001_initial.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=3').get()) {
        await db.exec(await readFile(new URL('../migrations/002_accounting_integrity.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=4').get()) {
        await db.exec(await readFile(new URL('../migrations/003_immutable_line_inserts.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=5').get()) {
        await db.exec(await readFile(new URL('../migrations/004_audited_editing.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=6').get()) {
        await db.exec(await readFile(new URL('../migrations/005_projects.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=7').get()) {
        await db.exec(await readFile(new URL('../migrations/006_company_settings.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=8').get()) {
        await db.exec(await readFile(new URL('../migrations/007_wallet_transaction_edits.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=9').get()) {
        await db.exec(await readFile(new URL('../migrations/008_commercial_documents.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=10').get()) {
        await db.exec(await readFile(new URL('../migrations/009_company_creation_commands.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=11').get()) {
        await db.exec(await readFile(new URL('../migrations/010_bank_imports.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=12').get()) {
        await db.exec(await readFile(new URL('../migrations/011_password_recovery.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=13').get()) {
        await db.exec(await readFile(new URL('../migrations/012_fixed_assets.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=14').get()) {
        await db.exec(await readFile(new URL('../migrations/013_employees.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=15').get()) {
        await db.exec(await readFile(new URL('../migrations/014_company_invitations.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=16').get()) {
        await db.exec(await readFile(new URL('../migrations/015_private_company_creation.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=17').get()) {
        await db.exec(await readFile(new URL('../migrations/016_cash_reconciliation.sql', import.meta.url), 'utf8'));
      }
      if (!await db.prepare('SELECT 1 FROM schema_versions WHERE version=18').get()) {
        await db.exec(await readFile(new URL('../migrations/017_bank_existing_entries.sql', import.meta.url), 'utf8'));
      }
    });
    return db;
  } catch (error) { await pool.end(); throw error; }
}

export async function transaction(db, fn) {
  if (context.getStore()?.db === db) throw new Error('Nested transactions are not allowed');
  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');
    const result = await context.run({ db, client }, fn);
    await client.query('COMMIT');
    return result;
  } catch (error) { await client.query('ROLLBACK'); throw error; }
  finally { client.release(); }
}
