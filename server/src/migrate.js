import { openDatabase } from './db.js';
const db = await openDatabase();
try { const row = await db.prepare('SELECT MAX(version) AS version FROM schema_versions').get(); console.log(`PostgreSQL schema version ${row.version}`); }
finally { await db.close(); }
