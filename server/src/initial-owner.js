import { randomUUID } from 'node:crypto';
import { transaction } from './db.js';
import { hashPassword, text, fail } from './security.js';

// Offline provisioning only: this is never exposed as an HTTP registration route.
export async function createInitialOwner(db, input) {
  const login = text(input.login, 'login', 254).toLowerCase();
  const name = text(input.name, 'name');
  if (typeof input.password !== 'string' || input.password.length < 12 || input.password.length > 256) {
    fail(400, 'password_length_12_to_256');
  }
  const password = await hashPassword(input.password);
  return transaction(db, async () => {
    // Concurrent provisioning processes must not create two first owners.
    await db.exec('SELECT pg_advisory_xact_lock(62700322)');
    if (await db.prepare('SELECT 1 FROM users LIMIT 1').get()) fail(409, 'initial_owner_already_exists');
    const user = { id: randomUUID(), login, name };
    await db.prepare('INSERT INTO users(id,login,password,name,created_at,can_create_companies) VALUES(?,?,?,?,?,TRUE)')
      .run(user.id, login, password, name, new Date().toISOString());
    return user;
  });
}
