import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { createApp } from '../src/app.js';

async function fixture(t, overrides = {}) {
  const dataDir = await mkdtemp(join(tmpdir(), 'm-uchet-'));
  const app = await createApp({ dataDir, allowRegistration: true, ...overrides });
  t.after(async () => { await app.close(); await rm(dataDir, { recursive: true, force: true }); });
  async function call(method, url, payload, token, key) {
    const response = await app.inject({ method, url, payload,
      headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), ...(key ? { 'idempotency-key': key } : {}) } });
    return { status: response.statusCode, body: response.json() };
  }
  async function user(login) {
    const registered = await call('POST', '/v1/auth/register', { login, name: login, password: 'correct-horse-battery' });
    assert.equal(registered.status, 201);
    const logged = await call('POST', '/v1/auth/login', { login, password: 'correct-horse-battery' });
    assert.equal(logged.status, 200);
    return { ...logged.body.user, token: logged.body.token };
  }
  const owner = await user('owner@example.test');
  const company = await call('POST', '/v1/companies', { name: 'Test Company', currency: 'KZT' }, owner.token);
  assert.equal(company.status, 201);
  const prefix = `/v1/companies/${company.body.id}`;
  const api = (method, path, payload, key = randomUUID()) => call(method, prefix + path, payload, owner.token, key);
  async function catalog() {
    const product = await api('POST', '/resources/nomenklatura', { data: { name: 'Product' } });
    const warehouse = await api('POST', '/resources/warehouses', { data: { name: 'Warehouse' } });
    assert.equal(product.status, 200); assert.equal(warehouse.status, 200);
    return { productId: product.body.id, warehouseId: warehouse.body.id };
  }
  return { app, call, user, owner, company: company.body, prefix, api, catalog, dataDir };
}

test('registration is closed by default, health does not require a session', async t => {
  const directory = await mkdtemp(join(tmpdir(), 'm-uchet-closed-'));
  const app = await createApp({ dataDir: directory, allowRegistration: false });
  t.after(async () => { await app.close(); await rm(directory, { recursive: true, force: true }); });
  assert.equal((await app.inject('/health')).json().status, 'ok');
  assert.equal((await app.inject({ method: 'POST', url: '/v1/auth/register', payload: { login: 'x' } })).statusCode, 403);
  assert.equal((await app.inject('/v1/companies')).statusCode, 401);
});

test('credentials, logout and password changes invalidate sessions', async t => {
  const f = await fixture(t);
  const bad = await f.call('POST', '/v1/auth/login', { login: f.owner.login, password: 'wrong' });
  assert.equal(bad.status, 401);
  const changed = await f.call('POST', '/v1/auth/password', { oldPassword: 'correct-horse-battery', password: 'new-password-long-enough' }, f.owner.token);
  assert.equal(changed.status, 200);
  assert.equal((await f.call('GET', '/v1/auth/me', undefined, f.owner.token)).status, 401);
  const session = await f.call('POST', '/v1/auth/login', { login: f.owner.login, password: 'new-password-long-enough' });
  assert.equal(session.status, 200);
  assert.equal((await f.call('POST', '/v1/auth/logout', undefined, session.body.token)).status, 200);
  assert.equal((await f.call('GET', '/v1/auth/me', undefined, session.body.token)).status, 401);
});

test('a company owner cannot read or mutate another company', async t => {
  const f = await fixture(t), outsider = await f.user('outsider@example.test');
  const other = await f.call('POST', '/v1/companies', { name: 'Other', currency: 'USD' }, outsider.token);
  assert.equal(other.status, 201);
  const doc = await f.api('POST', '/resources/clients', { data: { name: 'Private' } });
  for (const [method, path, payload] of [
    ['GET', '/resources/clients'],
    ['GET', `/resources/clients/${doc.body.id}`],
    ['POST', '/resources/clients', { data: { name: 'Injection' } }],
    ['GET', '/accounting/journal'], ['GET', '/audit'],
    ['PUT', `/members/${outsider.id}`, { permissions: ['catalog.read'] }],
  ]) assert.equal((await f.call(method, f.prefix + path, payload, outsider.token)).status, 404);
  const companies = await f.call('GET', '/v1/companies', undefined, outsider.token);
  assert.deepEqual(companies.body.map(c => c.id), [other.body.id]);
});

test('permissions are explicit, owner is protected and revoked membership takes effect immediately', async t => {
  const f = await fixture(t), member = await f.user('member@example.test');
  assert.equal((await f.api('PUT', `/members/${member.id}`, { permissions: ['catalog.read'] })).status, 200);
  assert.equal((await f.call('GET', f.prefix + '/resources/clients', undefined, member.token)).status, 200);
  assert.equal((await f.call('POST', f.prefix + '/resources/clients', { data: { name: 'No' } }, member.token)).status, 403);
  assert.equal((await f.call('PUT', f.prefix + `/members/${member.id}`, { permissions: ['accounting.post'] }, member.token)).status, 403);
  assert.equal((await f.api('PUT', `/members/${member.id}`, { permissions: ['*'] })).status, 400);
  assert.equal((await f.api('DELETE', `/members/${f.owner.id}`)).status, 409);
  assert.equal((await f.api('DELETE', `/members/${member.id}`)).status, 200);
  assert.equal((await f.call('GET', f.prefix + '/resources/clients', undefined, member.token)).status, 404);
});

test('resources reject server-owned fields, private collections and stale writes', async t => {
  const f = await fixture(t);
  assert.equal((await f.api('POST', '/resources/clients', { data: { companyId: 'other' } })).status, 400);
  for (const kind of ['users','roles','security_pins','accounting_entries','__proto__']) {
    assert.equal((await f.api('POST', `/resources/${kind}`, { data: { name: 'No' } })).status, 404);
  }
  const doc = await f.api('POST', '/resources/clients', { data: { name: 'Before' } });
  assert.equal((await f.api('PUT', `/resources/clients/${doc.body.id}`, { version: 1, data: { name: 'After' } })).status, 200);
  assert.equal((await f.api('PUT', `/resources/clients/${doc.body.id}`, { version: 1, data: { name: 'Lost update' } })).status, 409);
  assert.equal((await f.api('GET', `/resources/clients/${doc.body.id}`)).body.data.name, 'After');
  assert.equal((await f.api('GET', '/resources/clients?limit=0')).status, 400);
});

test('receipt is atomic, company references are checked and duplicate requests do not add stock', async t => {
  const f = await fixture(t), refs = await f.catalog();
  const body = { ...refs, quantity: 10, unitCost: 150, scope: 'ACCOUNTING' }, key = randomUUID();
  const first = await f.api('POST', '/inventory/receipts', body, key);
  assert.equal(first.status, 200);
  assert.deepEqual((await f.api('POST', '/inventory/receipts', body, key)).body, first.body);
  assert.equal((await f.api('POST', '/inventory/receipts', { ...body, quantity: 11 }, key)).status, 409);
  assert.equal((await f.api('POST', '/inventory/receipts', { ...body, productId: 'foreign' })).status, 404);
  assert.equal((await f.api('POST', '/inventory/receipts', { ...body, quantity: -1 })).status, 400);
  assert.equal((await f.api('GET', '/inventory')).body.items.length, 1);
  const journal = await f.api('GET', '/accounting/journal');
  assert.equal(journal.body.items.length, 1);
  assert.equal(journal.body.items[0].lines[0].debit, 1500);
});

test('FIFO sale posts revenue and COGS once, payment settles receivable', async t => {
  const f = await fixture(t), refs = await f.catalog();
  for (const [quantity, unitCost] of [[2,100],[3,200]]) assert.equal((await f.api('POST', '/inventory/receipts', { ...refs, quantity, unitCost })).status, 200);
  const order = await f.api('POST', '/orders', { items: [{ ...refs, quantity: 4, unitPrice: 300 }] });
  assert.equal(order.status, 200);
  const path = `/orders/${order.body.id}`;
  assert.equal((await f.api('POST', path + '/reserve')).status, 200);
  const key = randomUUID(), shipped = await f.api('POST', path + '/ship', undefined, key);
  assert.equal(shipped.status, 200);
  assert.equal(shipped.body.cogs, 600); assert.equal(shipped.body.grossProfit, 600);
  assert.deepEqual((await f.api('POST', path + '/ship', undefined, key)).body, shipped.body);
  assert.equal((await f.api('POST', path + '/ship')).status, 409);
  assert.equal((await f.api('POST', path + '/cancel')).status, 409);
  assert.equal((await f.api('POST', path + '/payments', { amount: 1300 })).status, 409);
  const paid = await f.api('POST', path + '/payments', { amount: 1200 });
  assert.equal(paid.status, 200); assert.equal(paid.body.outstanding, 0);
  assert.equal((await f.api('GET', path)).body.status, 'CLOSED');
  const accounts = (await f.api('GET', '/accounting/trial-balance')).body.accounts;
  assert.equal(accounts.find(a => a.account === 'receivables').balance, 0);
  assert.equal(accounts.find(a => a.account === 'inventory').balance, 200);
  assert.equal(accounts.find(a => a.account === 'cash').balance, 1200);
  assert.equal(accounts.reduce((sum, a) => sum + a.balance, 0), 0);
});

test('failed reservation rolls back earlier lines and audit/idempotency records', async t => {
  const f = await fixture(t), refs = await f.catalog();
  await f.api('POST', '/inventory/receipts', { ...refs, quantity: 5, unitCost: 100 });
  const second = await f.api('POST', '/resources/nomenklatura', { data: { name: 'Out of stock' } });
  const order = await f.api('POST', '/orders', { items: [{ ...refs, quantity: 2, unitPrice: 100 }, { ...refs, productId: second.body.id, quantity: 1, unitPrice: 100 }] });
  const result = await f.api('POST', `/orders/${order.body.id}/reserve`);
  assert.equal(result.status, 409);
  assert.equal((await f.api('GET', '/inventory')).body.items[0].reserved, 0);
  assert.equal((await f.api('GET', `/orders/${order.body.id}`)).body.status, 'NEW');
  assert.equal(f.app.db.prepare('SELECT count(*) AS n FROM reservations').get().n, 0);
  assert.equal(f.app.db.prepare("SELECT count(*) AS n FROM audit WHERE action='order.reserve'").get().n, 0);
});

test('reservations prevent overselling and cancellation releases stock', async t => {
  const f = await fixture(t), refs = await f.catalog();
  await f.api('POST', '/inventory/receipts', { ...refs, quantity: 5, unitCost: 100 });
  const orders = [];
  for (let i = 0; i < 2; i++) orders.push((await f.api('POST', '/orders', { items: [{ ...refs, quantity: 4, unitPrice: 100 }] })).body.id);
  const results = await Promise.all(orders.map(id => f.api('POST', `/orders/${id}/reserve`)));
  assert.deepEqual(results.map(r => r.status).sort(), [200,409]);
  const winner = orders[results.findIndex(r => r.status === 200)], loser = orders[results.findIndex(r => r.status === 409)];
  assert.equal((await f.api('POST', `/orders/${winner}/cancel`)).status, 200);
  assert.equal((await f.api('POST', `/orders/${loser}/reserve`)).status, 200);
});

test('unbalanced journals and unsafe amounts are rejected without writes', async t => {
  const f = await fixture(t);
  for (const lines of [
    [{ account: 'cash', debit: 100 }, { account: 'revenue', credit: 99 }],
    [{ account: 'cash', debit: 1.5 }, { account: 'revenue', credit: 1.5 }],
    [{ account: 'cash', debit: 10, credit: 10 }, { account: 'revenue', credit: 10 }],
    [{ account: 'cash', debit: Number.MAX_SAFE_INTEGER }, { account: 'revenue', credit: Number.MAX_SAFE_INTEGER }],
  ]) assert.equal((await f.api('POST', '/accounting/journal', { description: 'Invalid', lines })).status, 400);
  assert.deepEqual((await f.api('GET', '/accounting/journal')).body.items, []);
});

test('management and accounting ledgers are distinct; BOTH entries counted once', async t => {
  const f = await fixture(t);
  for (const [scope, amount] of [['ACCOUNTING',100],['MANAGEMENT',200],['BOTH',50]]) {
    assert.equal((await f.api('POST', '/accounting/journal', { scope, description: 'Opening', lines: [{ account: 'cash', debit: amount }, { account: 'capital', credit: amount }] })).status, 200);
  }
  for (const [scope, expected] of [['ACCOUNTING',150],['MANAGEMENT',250],['BOTH',50]]) {
    const report = await f.api('GET', `/accounting/trial-balance?scope=${scope}`);
    assert.equal(report.body.accounts.find(a => a.account === 'cash').balance, expected);
  }
});

test('files require company membership and are served as attachments', async t => {
  const f = await fixture(t), outsider = await f.user('files-outsider@example.test');
  const payload = Buffer.from('--boundary\r\nContent-Disposition: form-data; name="file"; filename="test.txt"\r\nContent-Type: text/plain\r\n\r\nprivate content\r\n--boundary--\r\n');
  const uploaded = await f.app.inject({ method: 'POST', url: f.prefix + '/files', payload, headers: { authorization: `Bearer ${f.owner.token}`, 'content-type': 'multipart/form-data; boundary=boundary' } });
  assert.equal(uploaded.statusCode, 200);
  const path = f.prefix + '/files/' + uploaded.json().id;
  assert.equal((await f.call('GET', path, undefined, outsider.token)).status, 404);
  const downloaded = await f.app.inject({ url: path, headers: { authorization: `Bearer ${f.owner.token}` } });
  assert.equal(downloaded.body, 'private content');
  assert.equal(downloaded.headers['content-type'], 'application/octet-stream');
  assert.match(downloaded.headers['content-disposition'], /^attachment;/);
});

test('database and migrations survive close/reopen without losing data', async t => {
  const directory = await mkdtemp(join(tmpdir(), 'm-uchet-restart-'));
  let app;
  t.after(async () => { if (app) await app.close(); await rm(directory, { recursive: true, force: true }); });
  app = await createApp({ dataDir: directory, allowRegistration: true });
  await app.inject({ method: 'POST', url: '/v1/auth/register', payload: { login: 'persistent', name: 'Persist', password: 'persistent-password' } });
  await app.close(); app = undefined;
  app = await createApp({ dataDir: directory });
  const login = await app.inject({ method: 'POST', url: '/v1/auth/login', payload: { login: 'persistent', password: 'persistent-password' } });
  assert.equal(login.statusCode, 200);
  assert.equal(app.db.prepare('SELECT count(*) AS n FROM schema_versions').get().n, 1);
});
