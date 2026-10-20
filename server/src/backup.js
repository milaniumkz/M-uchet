import { backup } from 'node:sqlite';
import { resolve } from 'node:path';
import { mkdirSync } from 'node:fs';
import { openDatabase } from './db.js';
const directory = resolve(process.env.DATA_DIR ?? './var');
const targetDir = resolve(process.env.BACKUP_DIR ?? './backups');
mkdirSync(targetDir, { recursive: true, mode: 0o700 });
const db = openDatabase(directory);
const target = resolve(targetDir, `uchet-${Date.now()}.sqlite`);
try { await backup(db, target); console.log(target); } finally { db.close(); }
