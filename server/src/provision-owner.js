import { openDatabase } from './db.js';
import { createInitialOwner } from './initial-owner.js';

// Passwords must not be supplied through argv or printed to a terminal/log.
async function readInput() {
  if (process.stdin.isTTY) throw new Error('Pipe a JSON object with login, name and password through stdin.');
  const chunks = [];
  let size = 0;
  for await (const chunk of process.stdin) {
    size += chunk.length;
    if (size > 8192) throw new Error('Provisioning input exceeds 8 KiB.');
    chunks.push(chunk);
  }
  const input = JSON.parse(Buffer.concat(chunks).toString('utf8'));
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error('JSON object required.');
  return input;
}
let db;
try {
  const input = await readInput();
  db = await openDatabase();
  await createInitialOwner(db, input);
  console.log('Initial owner created. Public registration remains disabled. Sign in to create your firm.');
} catch (error) {
  // Do not log the input, credential values, database URLs or driver parameters.
  console.error(error.code === 'initial_owner_already_exists'
    ? 'An account already exists. Initial provisioning refused; no accounts changed.'
    : 'Owner provisioning failed. Check the JSON input, password length (12–256), database configuration and migrations.');
  process.exitCode = 1;
} finally { if (db) await db.close(); }
