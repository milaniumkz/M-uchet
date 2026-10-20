import { Writable } from 'node:stream';
import { privateLoggerOptions } from '../src/logging.js';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { createApp } from '../src/app.js';
import { transaction } from '../src/db.js';
import { accountReference } from '../src/legal.js';

const testSchema = () => 'test_' + randomUUID().replaceAll('-', '');
test('2026 account reference cannot silently apply the published future 2027 version',()=>{
 const chart=accountReference('2026-12-31');
 assert.equal(chart.accounts.find(a=>a.code==='1010').name,'Денежные средства в кассе');
 assert.throws(()=>accountReference('2027-01-01'),error=>error.statusCode===422);
 assert.throws(()=>accountReference('2025-12-31'),error=>error.statusCode===422);
});
async function fixture(t, overrides = {}) {
  const dataDir = await mkdtemp(join(tmpdir(), 'm-uchet-'));
  const app = await createApp({ dataDir, schema: testSchema(), allowRegistration: true, ...overrides });
  t.after(async () => { await app.db.exec(`DROP SCHEMA "${app.db.schema}" CASCADE`); await app.close(); await rm(dataDir, { recursive: true, force: true }); });
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
  const app = await createApp({ dataDir: directory, schema: testSchema(), allowRegistration: false });
  t.after(async () => { await app.db.exec(`DROP SCHEMA "${app.db.schema}" CASCADE`); await app.close(); await rm(directory, { recursive: true, force: true }); });
  assert.equal((await app.inject('/health')).json().status, 'ok');
  assert.equal((await app.inject({ method: 'POST', url: '/v1/auth/register', payload: { login: 'x' } })).statusCode, 403);
  assert.equal((await app.inject('/v1/companies')).statusCode, 401);
});

test('credentials, logout and password changes invalidate sessions', async t => {
  const f = await fixture(t);
  const bad = await f.call('POST', '/v1/auth/login', { login: f.owner.login, password: 'wrong' });
  assert.equal(bad.status, 401);
  const incorrect=await f.call('POST','/v1/auth/password',{oldPassword:'incorrect-password',password:'new-password-long-enough'},f.owner.token);
  assert.equal(incorrect.status,403);assert.equal(incorrect.body.error,'current_password_incorrect');
  assert.equal((await f.call('GET','/v1/auth/me',undefined,f.owner.token)).status,200);
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
  assert.equal((await f.app.db.prepare('SELECT count(*) AS n FROM reservations').get()).n, 0);
  assert.equal((await f.app.db.prepare("SELECT count(*) AS n FROM audit WHERE action='order.reserve'").get()).n, 0);
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
  const schema = testSchema();
  const directory = await mkdtemp(join(tmpdir(), 'm-uchet-restart-'));
  let app;
  t.after(async () => { if (app) await app.db.exec(`DROP SCHEMA "${app.db.schema}" CASCADE`); await app.close(); await rm(directory, { recursive: true, force: true }); });
  app = await createApp({ dataDir: directory, schema, allowRegistration: true });
  await app.inject({ method: 'POST', url: '/v1/auth/register', payload: { login: 'persistent', name: 'Persist', password: 'persistent-password' } });
  await app.close(); app = undefined;
  app = await createApp({ dataDir: directory, schema });
  const login = await app.inject({ method: 'POST', url: '/v1/auth/login', payload: { login: 'persistent', password: 'persistent-password' } });
  assert.equal(login.statusCode, 200);
  assert.equal((await app.db.prepare('SELECT count(*) AS n FROM schema_versions').get()).n, 22);
});

test('wallet transfers and debt settlements are atomic and idempotent', async t => {
  const f = await fixture(t);
  const one = (await f.api('POST', '/wallets', { name: 'Cash' })).body;
  const two = (await f.api('POST', '/wallets', { name: 'Bank' })).body;
  assert.ok(one.id); assert.ok(two.id);
  assert.equal((await f.api('POST', `/wallets/${one.id}/transactions`, { type: 'CAPITAL', amount: 1000, description: 'Opening capital' })).status, 200);
  const transfer = { sourceWalletId: one.id, targetWalletId: two.id, amount: 400 }, key = randomUUID();
  assert.equal((await f.api('POST', '/wallet-transfers', transfer, key)).status, 200);
  assert.equal((await f.api('POST', '/wallet-transfers', transfer, key)).status, 200);
  assert.equal((await f.api('POST', '/wallet-transfers', { ...transfer, amount: 800 })).status, 409);
  const balances = (await f.api('GET', '/wallets')).body.items;
  assert.equal(balances.find(w => w.id === one.id).balance, 600);
  assert.equal(balances.find(w => w.id === two.id).balance, 400);
  const client = (await f.api('POST', '/resources/clients', { data: { name: 'Synthetic client' } })).body;
  const debt = await f.api('POST', '/debts', { type: 'AR', counterpartyId: client.id, amount: 500, dueDate: '2026-10-31' });
  assert.equal(debt.status, 200);
  const paid = await f.api('POST', `/debts/${debt.body.id}/settlements`, { walletId: two.id, amount: 300 });
  assert.equal(paid.status, 200); assert.equal(paid.body.remaining, 200);
  assert.equal((await f.api('POST', `/debts/${debt.body.id}/settlements`, { walletId: two.id, amount: 300 })).status, 409);
  assert.equal((await f.api('GET', `/debts/${debt.body.id}/payments`)).body.items.length, 1);
});

test('stock transfers preserve cost; writeoffs cannot consume reserved units', async t => {
  const f = await fixture(t), refs = await f.catalog();
  const target = (await f.api('POST', '/resources/warehouses', { data: { name: 'Target' } })).body;
  await f.api('POST', '/inventory/receipts', { ...refs, quantity: 10, unitCost: 125 });
  const move = await f.api('POST', '/inventory/movements', { productId: refs.productId, sourceWarehouseId: refs.warehouseId, targetWarehouseId: target.id, quantity: 4 });
  assert.equal(move.status, 200); assert.equal(move.body.cost, 500);
  const order = (await f.api('POST', '/orders', { items: [{ ...refs, quantity: 5, unitPrice: 200 }] })).body;
  await f.api('POST', `/orders/${order.id}/reserve`);
  assert.equal((await f.api('POST', '/inventory/writeoffs', { ...refs, quantity: 2, reason: 'Damaged' })).status, 409);
  const written = await f.api('POST', '/inventory/writeoffs', { ...refs, quantity: 1, reason: 'Damaged' });
  assert.equal(written.status, 200); assert.equal(written.body.cost, 125);
  const rows = (await f.api('GET', '/inventory')).body.items;
  assert.equal(rows.reduce((sum, b) => sum + b.quantity, 0), 9);
  assert.equal(rows.reduce((sum, b) => sum + b.quantity * b.unit_cost, 0), 1125);
});

test('cash shifts and device command transitions cannot execute twice', async t => {
  const f = await fixture(t);
  const wallet = (await f.api('POST', '/wallets', { name: 'Cash' })).body;
  const shift = await f.api('POST', '/shifts', { walletId: wallet.id }); assert.equal(shift.status, 200);
  assert.equal((await f.api('POST', '/shifts', { walletId: wallet.id })).status, 409);
  assert.equal((await f.api('POST', `/shifts/${shift.body.id}/close`, { countedAmount: 0 })).status, 200);
  assert.equal((await f.api('POST', `/shifts/${shift.body.id}/close`, { countedAmount: 0 })).status, 409);
  const device = (await f.api('POST', '/resources/devices', { data: { name: 'Test terminal' } })).body;
  const cmd = await f.api('POST', `/devices/${device.id}/commands`, { command: 'SYNC' }); assert.equal(cmd.status, 200);
  assert.equal((await f.api('POST', `/devices/${device.id}/commands/${cmd.body.id}/acknowledge`, { status: 'SUCCEEDED' })).status, 200);
  assert.equal((await f.api('POST', `/devices/${device.id}/commands/${cmd.body.id}/acknowledge`, { status: 'SUCCEEDED' })).status, 409);
});

test('manual reversal preserves history and restores balanced trial balance', async t => {
  const f = await fixture(t);
  const entry = await f.api('POST', '/accounting/journal', { description: 'Opening', lines: [{ account: 'cash', debit: 123 }, { account: 'capital', credit: 123 }] });
  assert.equal(entry.status, 200);
  assert.equal((await f.api('POST', `/accounting/journal/${entry.body.id}/reverse`, { reason: 'Correction' })).status, 200);
  assert.equal((await f.api('POST', `/accounting/journal/${entry.body.id}/reverse`, { reason: 'Again' })).status, 409);
  const report = (await f.api('GET', '/accounting/trial-balance')).body;
  assert.ok(report.accounts.every(a => a.balance === 0));
  assert.equal((await f.api('GET', '/accounting/journal')).body.items.length, 2);
});

test('closed periods remain editable on owner request; replay preserves history', async t => {
  const f=await fixture(t), key=randomUUID();
  const payload={businessDate:'2026-03-10',description:'Synthetic historical opening',lines:[{account:'cash',debit:123},{account:'capital',credit:123}]};
  const first=await f.api('POST','/accounting/journal',payload,key);assert.equal(first.status,200);
  assert.equal((await f.api('POST','/periods/2026-03/close',{reason:'Synthetic close'})).status,200);
  assert.deepEqual((await f.api('POST','/accounting/journal',payload,key)).body,first.body);
  assert.equal((await f.api('POST','/accounting/journal',payload)).status,200);
  assert.equal((await f.api('POST','/periods/2026-03/reopen',{reason:'Controlled correction'})).status,200);
  assert.equal((await f.api('POST','/accounting/journal',payload)).status,200);
});

test('PostgreSQL rejects unbalanced entries and records history for edits',async t=>{
 const f=await fixture(t);
 await assert.rejects(transaction(f.app.db,async()=>{
  await f.app.db.prepare('INSERT INTO journal(id,company_id,scope,currency,description,lines,created_at,business_date) VALUES(?,?,?,?,?,?,?,?)').run(randomUUID(),f.company.id,'ACCOUNTING','KZT','Invalid','[]',new Date().toISOString(),'2026-03-10');
 }),error=>error.code==='23514');
 const posted=await f.api('POST','/accounting/journal',{description:'Immutable',lines:[{account:'cash',debit:1},{account:'capital',credit:1}]});
 await f.app.db.prepare('UPDATE journal SET description=? WHERE id=?').run('Audited edit',posted.body.id);
 assert.equal((await f.app.db.prepare('SELECT count(*) AS n FROM journal_history WHERE entry_id=?').get(posted.body.id)).n,1);
 await assert.rejects(f.app.db.prepare('INSERT INTO journal_lines VALUES(?,?,?,?,?)').run(posted.body.id,2,'cash',1,0),error=>error.code==='23514');
});

test('concurrent API instances deduplicate the same receipt through PostgreSQL locks',async t=>{
 const f=await fixture(t),refs=await f.catalog(),key=randomUUID();
 const second=await createApp({schema:f.app.db.schema,dataDir:f.dataDir});t.after(()=>second.close());
 const request={method:'POST',url:f.prefix+'/inventory/receipts',payload:{...refs,quantity:7,unitCost:10},headers:{authorization:`Bearer ${f.owner.token}`,'idempotency-key':key}};
 const results=await Promise.all([f.app.inject(request),second.inject(request)]);
 assert.deepEqual(results.map(r=>r.statusCode),[200,200]);assert.deepEqual(results[0].json(),results[1].json());
 assert.equal((await f.api('GET','/inventory')).body.items.length,1);
});


test('owner can edit a posted journal and wallet balance after closing the period',async t=>{
 const f=await fixture(t);
 const posted=await f.api('POST','/accounting/journal',{businessDate:'2026-03-10',description:'Original',lines:[{account:'cash',debit:100},{account:'capital',credit:100}]});
 await f.api('POST','/periods/2026-03/close',{reason:'Close'});
 const changed=await f.api('PUT',`/accounting/journal/${posted.body.id}`,{businessDate:'2026-03-10',description:'Edited',lines:[{account:'cash',debit:250},{account:'capital',credit:250}]});
 assert.equal(changed.status,200);assert.equal(changed.body.id,posted.body.id);
 const history=await f.api('GET',`/accounting/journal/${posted.body.id}/history`);assert.equal(history.body.items.length,1);assert.equal(history.body.items[0].snapshot.description,'Manual: Original');
 const wallet=(await f.api('POST','/wallets',{name:'Before'})).body;
 const edit=await f.api('PUT',`/wallets/${wallet.id}`,{name:'After',balance:1000});assert.equal(edit.status,200);assert.equal(edit.body.balance,1000);
 assert.equal((await f.api('GET',`/wallets/${wallet.id}/entries`)).body.items[0].kind,'BALANCE_EDIT');
});

test('owner can edit a closed paid sale; stock, COGS, revenue and customer credit reconcile',async t=>{
 const f=await fixture(t),refs=await f.catalog();
 await f.api('POST','/inventory/receipts',{...refs,quantity:10,unitCost:100});
 const order=(await f.api('POST','/orders',{items:[{...refs,quantity:4,unitPrice:200}]})).body;
 await f.api('POST',`/orders/${order.id}/reserve`);await f.api('POST',`/orders/${order.id}/ship`);await f.api('POST',`/orders/${order.id}/payments`,{amount:800});
 const edit=await f.api('PUT',`/orders/${order.id}`,{items:[{...refs,quantity:3,unitPrice:200}]});
 assert.equal(edit.status,200);assert.equal(edit.body.status,'CLOSED');assert.equal(edit.body.customerCredit,200);
 assert.equal((await f.api('GET','/inventory')).body.items[0].quantity,7);
 const report=(await f.api('GET','/accounting/trial-balance')).body.accounts;
 assert.equal(report.find(a=>a.account==='revenue').balance,-600);assert.equal(report.find(a=>a.account==='cogs').balance,300);
 assert.equal(report.find(a=>a.account==='customer_advances').balance,-200);assert.equal(report.reduce((sum,a)=>sum+a.balance,0),0);
 assert.equal((await f.api('GET',`/orders/${order.id}/history`)).body.items.length,1);
 const bad=await f.api('PUT',`/orders/${order.id}`,{items:[{...refs,quantity:11,unitPrice:200}]});assert.equal(bad.status,409);
 assert.equal((await f.api('GET','/inventory')).body.items[0].quantity,7);
});

test('dynamic projects reconcile with company totals and reject foreign project references', async t => {
  const f=await fixture(t);
  const a=await f.api('POST','/projects',{name:'Произвольный проект'});
  const b=await f.api('POST','/projects',{name:'Другой продукт'});
  assert.equal(a.status,200);assert.equal(b.status,200);
  const wallet=await f.api('POST','/wallets',{name:'Общий кошелёк'});
  for(const [type,amount,projectId] of [['INCOME',10000,a.body.id],['EXPENSE',3000,a.body.id],['INCOME',2000,b.body.id],['EXPENSE',5000,b.body.id],['EXPENSE',1000,null]]){
    assert.equal((await f.api('POST',`/wallets/${wallet.body.id}/transactions`,{type,amount,projectId,description:'Операция'})).status,200);
  }
  const report=await f.api('GET','/reports/projects');
  assert.equal(report.status,200);
  assert.equal(report.body.items.find(p=>p.projectId===a.body.id).netProfit,7000);
  assert.equal(report.body.items.find(p=>p.projectId===b.body.id).netProfit,-3000);
  assert.equal(report.body.items.find(p=>p.projectId===null).netProfit,-1000);
  assert.equal(report.body.total.netProfit,3000);
  assert.equal((await f.api('GET','/reports/profit-loss')).body.netProfit,3000);
  const outsider=await f.user('outsider-project@example.test');
  const other=await f.call('POST','/v1/companies',{name:'Other',currency:'KZT'},outsider.token);
  const foreign=await f.call('POST',`/v1/companies/${other.body.id}/projects`,{name:'Чужой'},outsider.token,randomUUID());
  assert.equal((await f.api('POST',`/wallets/${wallet.body.id}/transactions`,{type:'INCOME',amount:1,projectId:foreign.body.id,description:'Denied'})).status,404);
  const rename=await f.api('PUT',`/projects/${a.body.id}`,{version:1,name:'Новое название',archived:true});
  assert.equal(rename.status,200);
  assert.equal((await f.api('GET',`/reports/projects?projectId=${a.body.id}`)).body.items[0].netProfit,7000);
});

test('a paid sale can move between projects without duplicating company profit',async t=>{
 const f=await fixture(t),refs=await f.catalog();
 const a=(await f.api('POST','/projects',{name:'Первый'})).body;
 const b=(await f.api('POST','/projects',{name:'Второй'})).body;
 await f.api('POST','/inventory/receipts',{...refs,quantity:10,unitCost:100});
 const order=(await f.api('POST','/orders',{projectId:a.id,items:[{...refs,quantity:4,unitPrice:200}]})).body;
 for(const action of ['reserve','ship'])assert.equal((await f.api('POST',`/orders/${order.id}/${action}`,{})).status,200);
 await f.api('POST',`/orders/${order.id}/payments`,{amount:800});
 const before=(await f.api('GET','/reports/projects')).body;
 assert.equal(before.items.find(p=>p.projectId===a.id).netProfit,400);
 const edited=await f.api('PUT',`/orders/${order.id}`,{projectId:b.id});
 assert.equal(edited.status,200);assert.equal(edited.body.status,'CLOSED');
 const after=(await f.api('GET','/reports/projects')).body;
 assert.equal(after.items.find(p=>p.projectId===a.id).netProfit,0);
 assert.equal(after.items.find(p=>p.projectId===b.id).netProfit,400);
 assert.equal((await f.api('GET',`/orders?projectId=${a.id}`)).body.items.length,0);
 assert.equal((await f.api('GET',`/orders?projectId=${b.id}`)).body.items[0].id,order.id);
 assert.ok((await f.api('GET',`/accounting/journal?projectId=${b.id}`)).body.items.every(j=>j.project_id===b.id));
 assert.deepEqual(after.total,before.total);
 assert.equal((await f.api('GET','/inventory')).body.items[0].quantity,6);
});


test('same-origin web assets do not bypass API auth or expose dotfiles',async t=>{
 const root=await mkdtemp(join(tmpdir(),'muchet-web-'));
 t.after(()=>rm(root,{recursive:true,force:true}));
 await writeFile(join(root,'index.html'),'<html><title>SYNTHETIC WEB FIXTURE</title></html>');
 await writeFile(join(root,'.env'),'SYNTHETIC PRIVATE FILE');
 const f=await fixture(t,{webRoot:root});
 const page=await f.app.inject('/');assert.equal(page.statusCode,200);assert.match(page.body,/SYNTHETIC WEB FIXTURE/);
 assert.equal((await f.app.inject('/v1/companies')).statusCode,401);
 assert.equal((await f.app.inject('/.env')).statusCode,403);
 assert.ok([403,404].includes((await f.app.inject('/%2e%2e/.env')).statusCode));
});


test('legal and tax settings belong to company, not to an individual project',async t=>{
 const f=await fixture(t);
 assert.equal((await f.api('GET','/settings')).body.version,0);
 const settings={version:0,legalName:'Синтетическая фирма',identifier:null,legalForm:'TOO',taxRegime:'GENERAL',vatRegistered:true};
 assert.equal((await f.api('PUT','/settings',{...settings,identifier:'invalid'})).status,400);
 const saved=await f.api('PUT','/settings',settings);assert.equal(saved.status,200);assert.equal(saved.body.version,1);
 await f.api('POST','/projects',{name:'Проект без собственного налогового режима'});
 assert.equal((await f.api('GET','/settings')).body.tax_regime,'GENERAL');
 assert.equal((await f.api('PUT','/settings',settings)).status,409);
 const outsider=await f.user('settings-outsider@example.test');
 assert.equal((await f.call('GET',f.prefix+'/settings',undefined,outsider.token)).status,404);
});


test('editing a money transaction updates wallet and project profit atomically',async t=>{
 const f=await fixture(t),project=(await f.api('POST','/projects',{name:'Новый проект'})).body;
 const wallet=(await f.api('POST','/wallets',{name:'Счёт'})).body;
 const income=(await f.api('POST',`/wallets/${wallet.id}/transactions`,{type:'INCOME',amount:1000,description:'Первый доход'})).body;
 await f.api('POST',`/wallets/${wallet.id}/transactions`,{type:'EXPENSE',amount:100,description:'Расход'});
 const path=`/wallets/${wallet.id}/entries/${income.entryId}`;
 assert.equal((await f.api('PUT',path,{amount:50})).status,409);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,900);
 const edit=await f.api('PUT',path,{amount:500,projectId:project.id,description:'Исправленный доход'});
 assert.equal(edit.status,200);assert.equal(edit.body.balance,400);
 const report=(await f.api('GET','/reports/projects')).body;
 assert.equal(report.total.netProfit,400);assert.equal(report.items.find(p=>p.projectId===project.id).netProfit,500);
 assert.equal(report.items.find(p=>p.projectId===null).netProfit,-100);
 const entry=(await f.api('GET',`/wallets/${wallet.id}/entries`)).body.items.find(e=>e.id===income.entryId);
 assert.equal(entry.amount,500);
 assert.equal((await f.api('GET',`/accounting/journal/${entry.journal_id}/history`)).body.items.length,1);
});


test('manual wallet journal edits keep the spendable balance consistent with the ledger',async t=>{
 const f=await fixture(t),wallet=(await f.api('POST','/wallets',{name:'Счёт'})).body;
 const entry=(await f.api('POST','/accounting/journal',{description:'Вклад',lines:[{account:`wallet:${wallet.id}`,debit:900},{account:'capital',credit:900}]})).body;
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,900);
 const revised=await f.api('PUT',`/accounting/journal/${entry.id}`,{lines:[{account:`wallet:${wallet.id}`,debit:600},{account:'capital',credit:600}]});
 assert.equal(revised.status,200);assert.equal((await f.api('GET','/wallets')).body.items[0].balance,600);
 const denied=await f.api('PUT',`/accounting/journal/${entry.id}`,{lines:[{account:`wallet:${wallet.id}`,credit:1},{account:'capital',debit:1}]});
 assert.equal(denied.status,409);assert.equal((await f.api('GET','/wallets')).body.items[0].balance,600);
});


test('manual journal permissions cannot bypass wallet transaction permissions',async t=>{
 const f=await fixture(t),wallet=(await f.api('POST','/wallets',{name:'Счёт'})).body;
 const member=await f.user('ledger-only@example.test');
 assert.equal((await f.api('PUT',`/members/${member.id}`,{permissions:['accounting.post']})).status,200);
 const posted=await f.call('POST',f.prefix+'/accounting/journal',{description:'No wallet permission',lines:[{account:`wallet:${wallet.id}`,debit:1},{account:'capital',credit:1}]},member.token,randomUUID());
 assert.equal(posted.status,403);assert.equal((await f.api('GET','/wallets')).body.items[0].balance,0);
});


async function commercialFixture(t,{vat=false}={}){
 const f=await fixture(t);
 await f.api('PUT','/settings',{version:0,legalName:'SYNTHETIC FIRM',identifier:'000000000000',legalForm:'TOO',taxRegime:'GENERAL',vatRegistered:vat});
 const client=(await f.api('POST','/resources/clients',{data:{name:'SYNTHETIC CLIENT',identifier:'000000000001'}})).body;
 const supplier=(await f.api('POST','/resources/suppliers',{data:{name:'SYNTHETIC SUPPLIER',identifier:'000000000002'}})).body;
 const wallet=(await f.api('POST','/wallets',{name:'BANK'})).body;
 const project=(await f.api('POST','/projects',{name:'Услуги IT'})).body;
 const body={kind:'SALE_ACT',counterpartyId:client.id,projectId:project.id,items:[{description:'Разработка',quantity:'1.000',unitPrice:10000}],businessDate:'2026-10-20'};
 return {...f,client,supplier,wallet,project,body};
}
test('service invoice advance converts to act without recognizing revenue twice',async t=>{
 const f=await commercialFixture(t);
 const invoice=await f.api('POST','/commercial-documents',{...f.body,kind:'SALE_INVOICE'});assert.equal(invoice.status,200);
 const id=invoice.body.id;
 assert.equal((await f.api('POST',`/commercial-documents/${id}/post`,{})).body.status,'ISSUED');
 const paid=await f.api('POST',`/commercial-documents/${id}/payments`,{walletId:f.wallet.id,amount:4000,businessDate:'2026-10-20'});assert.equal(paid.status,200);
 assert.equal((await f.api('GET','/reports/projects')).body.total.revenue,0);
 const act=(await f.api('POST',`/commercial-documents/${id}/act`,{})).body;
 assert.equal((await f.api('POST',`/commercial-documents/${id}/act`,{})).body.id,act.id);
 const posted=await f.api('POST',`/commercial-documents/${act.id}/post`,{});assert.equal(posted.status,200);assert.equal(posted.body.outstanding,6000);
 const list=(await f.api('GET','/commercial-documents?limit=1')).body;
 assert.equal(list.items.length,1);assert.equal(list.summary.count,2);assert.equal(list.summary.drafts,0);assert.equal(list.summary.outstanding,6000);
 assert.equal((await f.api('GET','/commercial-documents?direction=purchases')).body.summary.count,0);
 assert.equal((await f.api('GET','/commercial-documents?projectId=unassigned')).body.summary.count,0);
 assert.equal((await f.api('GET','/reports/projects')).body.total.revenue,10000);
 assert.equal((await f.api('POST',`/commercial-documents/${act.id}/payments`,{walletId:f.wallet.id,amount:6000,businessDate:'2026-10-21'})).status,200);
 assert.equal((await f.api('GET',`/commercial-documents/${act.id}`)).body.outstanding,0);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,10000);
 assert.equal((await f.api('GET','/inventory')).body.items.length,0);
 const trial=(await f.api('GET','/accounting/trial-balance')).body.accounts;
 assert.equal(trial.find(a=>a.account==='receivables').balance,0);
 assert.equal((trial.find(a=>a.account==='customer_advances')?.balance??0),0);
});
test('posted paid act can change project and amount, cancel and restore with exact balances',async t=>{
 const f=await commercialFixture(t),other=(await f.api('POST','/projects',{name:'Другой проект'})).body;
 let act=(await f.api('POST','/commercial-documents',f.body)).body;
 act=(await f.api('POST',`/commercial-documents/${act.id}/post`,{})).body;
 assert.equal((await f.api('POST',`/commercial-documents/${act.id}/payments`,{walletId:f.wallet.id,amount:10000,businessDate:'2026-10-21'})).status,200);
 let edit=await f.api('PUT',`/commercial-documents/${act.id}`,{version:act.version,projectId:other.id,items:[{description:'Исправленный объём',quantity:'0.500',unitPrice:10000}]});
 assert.equal(edit.status,200);assert.equal(edit.body.customerCredit,5000);
 let report=(await f.api('GET','/reports/projects')).body;
 assert.equal(report.items.find(p=>p.projectId===f.project.id).netProfit,0);assert.equal(report.items.find(p=>p.projectId===other.id).netProfit,5000);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,10000);
 assert.equal((await f.api('POST',`/commercial-documents/${act.id}/cancel`,{})).status,200);
 assert.equal((await f.api('GET','/reports/projects')).body.total.revenue,0);
 let trial=(await f.api('GET','/accounting/trial-balance')).body.accounts;
 assert.equal(trial.find(a=>a.account==='customer_advances').balance,-10000);assert.equal(trial.find(a=>a.account==='receivables').balance,0);
 assert.equal((await f.api('POST',`/commercial-documents/${act.id}/post`,{})).status,200);
 assert.equal((await f.api('GET','/reports/projects')).body.total.revenue,5000);
 assert.ok((await f.api('GET',`/commercial-documents/${act.id}/history`)).body.items.length>=4);
});
test('service VAT calculations are exact and pending input VAT is not a claimed deduction',async t=>{
 const f=await commercialFixture(t,{vat:true});
 let sale=await f.api('POST','/commercial-documents',{...f.body,vatBasisPoints:1600,items:[{description:'Часть услуги',quantity:'0.125',unitPrice:123}]});
 assert.equal(sale.status,200);assert.equal(sale.body.data.net,15);assert.equal(sale.body.data.vat,2);assert.equal(sale.body.data.total,17);
 assert.equal((await f.api('POST',`/commercial-documents/${sale.body.id}/post`,{})).status,200);
 assert.equal((await f.api('GET','/reports/projects')).body.total.revenue,15);
 let purchase=await f.api('POST','/commercial-documents',{...f.body,kind:'PURCHASE_ACT',counterpartyId:f.supplier.id,vatBasisPoints:1600,vatTreatment:'PENDING'});
 assert.equal(purchase.status,200);assert.equal((await f.api('POST',`/commercial-documents/${purchase.body.id}/post`,{})).status,200);
 const trial=(await f.api('GET','/accounting/trial-balance')).body.accounts;
 assert.equal(trial.find(a=>a.account==='vat_payable').balance,-2);assert.equal(trial.find(a=>a.account==='pending_input_vat').balance,1600);
 assert.equal((await f.api('GET','/reports/projects')).body.total.expenses,10000);
 assert.equal((await f.api('POST','/commercial-documents',{...f.body,vatBasisPoints:1600,businessDate:'2027-01-01'})).status,422);
});
test('document numbers withstand concurrent creation; cross-company references and stale edits fail',async t=>{
 const f=await commercialFixture(t);
 const docs=await Promise.all(Array.from({length:8},()=>f.api('POST','/commercial-documents',f.body)));
 assert.ok(docs.every(d=>d.status===200));assert.equal(new Set(docs.map(d=>d.body.number)).size,8);
 const doc=docs[0].body;
 assert.equal((await f.api('PUT',`/commercial-documents/${doc.id}`,{version:99,note:'Stale'})).status,409);
 const outsider=await f.user('document-outsider@example.test');
 assert.equal((await f.call('GET',f.prefix+`/commercial-documents/${doc.id}`,undefined,outsider.token)).status,404);
 assert.equal((await f.api('POST','/commercial-documents',{...f.body,counterpartyId:'foreign'})).status,404);
});

test('purchase service payment can be edited, voided and restored without stock or duplicate expenses',async t=>{
 const f=await commercialFixture(t);
 await f.api('POST',`/wallets/${f.wallet.id}/transactions`,{type:'CAPITAL',amount:30000,description:'Funding'});
 let doc=(await f.api('POST','/commercial-documents',{...f.body,kind:'PURCHASE_ACT',counterpartyId:f.supplier.id,vatBasisPoints:1600})).body;
 doc=(await f.api('POST',`/commercial-documents/${doc.id}/post`,{})).body;
 const paid=await f.api('POST',`/commercial-documents/${doc.id}/payments`,{walletId:f.wallet.id,amount:4600,businessDate:'2026-10-21'});assert.equal(paid.status,200);
 const path=`/commercial-documents/${doc.id}/payments/${paid.body.id}`;
 assert.equal((await f.api('PUT',path,{amount:6000})).status,200);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,24000);
 assert.equal((await f.api('GET','/reports/projects')).body.total.expenses,11600);
 assert.equal((await f.api('POST',path+'/void',{})).status,200);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,30000);
 assert.equal((await f.api('GET',`/commercial-documents/${doc.id}`)).body.outstanding,11600);
 assert.equal((await f.api('POST',path+'/restore',{})).status,200);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,24000);
 assert.equal((await f.api('GET',`/commercial-documents/${doc.id}`)).body.outstanding,5600);
 assert.equal((await f.api('GET','/inventory')).body.items.length,0);
});
test('moving act after its payment date reclassifies payment as an advance until recognition',async t=>{
 const f=await commercialFixture(t);
 let doc=(await f.api('POST','/commercial-documents',f.body)).body;
 doc=(await f.api('POST',`/commercial-documents/${doc.id}/post`,{})).body;
 await f.api('POST',`/commercial-documents/${doc.id}/payments`,{walletId:f.wallet.id,amount:10000,businessDate:'2026-10-21'});
 assert.equal((await f.api('PUT',`/commercial-documents/${doc.id}`,{version:doc.version,businessDate:'2026-10-25'})).status,200);
 assert.equal((await f.api('GET','/reports/projects?to=2026-10-21')).body.total.revenue,0);
 assert.equal((await f.api('GET','/reports/projects?to=2026-10-25')).body.total.revenue,10000);
 const row=await f.app.db.prepare("SELECT SUM(l.debit-l.credit) AS balance FROM journal_lines l JOIN journal j ON j.id=l.entry_id WHERE j.company_id=? AND j.business_date<=? AND l.account='customer_advances'").get(f.company.id,'2026-10-21');
 assert.equal(row.balance,-10000);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,10000);
});
test('print export is authorized, escapes client text and metadata mutations replay safely',async t=>{
 const f=await commercialFixture(t);
 const key=randomUUID(),body={data:{name:'<script>BAD</script>'}};
 const a=await f.api('POST','/resources/clients',body,key),b=await f.api('POST','/resources/clients',body,key);assert.equal(a.body.id,b.body.id);
 const doc=(await f.api('POST','/commercial-documents',{...f.body,counterpartyId:a.body.id})).body;
 const printed=await f.app.inject({url:f.prefix+`/commercial-documents/${doc.id}/print`,headers:{authorization:`Bearer ${f.owner.token}`}});
 assert.equal(printed.statusCode,200);assert.ok(printed.body.includes('&lt;script&gt;BAD&lt;/script&gt;'));assert.ok(!printed.body.includes('<script>BAD'));
 assert.match(printed.headers['content-security-policy'],/default-src 'none'/);
 const member=await f.user('reader-no-export@example.test');await f.api('PUT',`/members/${member.id}`,{permissions:['documents.read']});
 assert.equal((await f.call('GET',f.prefix+`/commercial-documents/${doc.id}/export-data`,undefined,member.token)).status,403);
});

test('commercial source edits preserve document/ledger links and attachments stay company-private',async t=>{
 const f=await commercialFixture(t);
 let doc=(await f.api('POST','/commercial-documents',f.body)).body;doc=(await f.api('POST',`/commercial-documents/${doc.id}/post`,{})).body;
 const movement=(await f.api('GET',`/commercial-documents/${doc.id}/movements`)).body.items.find(m=>m.active);
 assert.equal((await f.api('PUT',`/accounting/journal/${movement.id}`,{lines:[{account:'receivables',debit:1},{account:'revenue',credit:1}]})).body.error,'source_document_edit_required');
 assert.equal((await f.api('PUT',`/commercial-documents/${doc.id}`,{version:doc.version,items:[{description:'Изменено',quantity:'1',unitPrice:1}]})).status,200);
 const upload=await f.app.inject({method:'POST',url:f.prefix+'/files',payload:Buffer.from('--b\r\nContent-Disposition: form-data; name="file"; filename="contract.txt"\r\nContent-Type: text/plain\r\n\r\nSYNTHETIC\r\n--b--\r\n'),headers:{authorization:`Bearer ${f.owner.token}`,'content-type':'multipart/form-data; boundary=b'}});
 assert.equal(upload.statusCode,200);
 const attached=await f.api('POST',`/commercial-documents/${doc.id}/files`,{fileId:upload.json().id});assert.equal(attached.status,200);
 assert.equal((await f.api('GET',`/commercial-documents/${doc.id}/files`)).body.items[0].id,upload.json().id);
 assert.equal((await f.api('POST',`/commercial-documents/${doc.id}/files`,{fileId:'foreign-file-id'})).status,404);
});

test('bank requisites validate checksum and document snapshots change only on explicit refresh',async t=>{
 const f=await commercialFixture(t);
 const bban='0000000000000000',checksum=String(98n-BigInt(bban+'203500')%97n).padStart(2,'0'),iban='KZ'+checksum+bban;
 let settings=(await f.api('GET','/settings')).body;
 const payload={version:settings.version,legalName:settings.legal_name,identifier:settings.identifier,legalForm:settings.legal_form,taxRegime:settings.tax_regime,vatRegistered:settings.vat_registered,bankIban:iban,bankBic:'TESTKZKX',legalAddress:'SYNTHETIC ADDRESS'};
 assert.equal((await f.api('PUT','/settings',{...payload,bankIban:iban.slice(0,-1)+'1'})).status,400);
 assert.equal((await f.api('PUT','/settings',payload)).status,200);
 let doc=(await f.api('POST','/commercial-documents',f.body)).body;
 assert.equal(doc.data.issuer.bank_iban,iban);
 settings=(await f.api('GET','/settings')).body;
 assert.equal((await f.api('PUT','/settings',{...payload,version:settings.version,legalName:'CHANGED SYNTHETIC NAME'})).status,200);
 doc=(await f.api('PUT',`/commercial-documents/${doc.id}`,{version:doc.version,note:'Edit note'})).body;
 assert.equal(doc.data.issuer.legal_name,payload.legalName);
 doc=(await f.api('PUT',`/commercial-documents/${doc.id}`,{version:doc.version,refreshIssuer:true})).body;
 assert.equal(doc.data.issuer.legal_name,'CHANGED SYNTHETIC NAME');
});


test('offline first owner provisioning is atomic, stores only hashes and keeps HTTP registration closed', async t => {
 const {createInitialOwner}=await import('../src/initial-owner.js');
 const {verifyPassword}=await import('../src/security.js');
 const dataDir=await mkdtemp(join(tmpdir(),'muchet-owner-'));
 const app=await createApp({dataDir,schema:testSchema(),allowRegistration:false});
 t.after(async()=>{await app.db.exec(`DROP SCHEMA "${app.db.schema}" CASCADE`);await app.close();await rm(dataDir,{recursive:true,force:true});});
 const call=async(method,url,payload,token)=>{const r=await app.inject({method,url,payload,headers:token?{authorization:'Bearer '+token}:{}});return {status:r.statusCode,body:r.json()};};
 const input={login:'OWNER@example.test',name:'SYNTHETIC INITIAL OWNER',password:randomUUID()};
 await assert.rejects(createInitialOwner(app.db,{...input,password:'short'}),e=>e.statusCode===400);
 const results=await Promise.allSettled([createInitialOwner(app.db,input),createInitialOwner(app.db,input)]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 assert.equal(results.find(r=>r.status==='rejected').reason.code,'initial_owner_already_exists');
 const stored=await app.db.prepare('SELECT * FROM users').all();assert.equal(stored.length,1);
 assert.equal(stored[0].login,'owner@example.test');assert.notEqual(stored[0].password,input.password);
 assert.equal(await verifyPassword(input.password,stored[0].password),true);
 assert.equal((await call('POST','/v1/auth/register',input)).status,403);
 const session=await call('POST','/v1/auth/login',{login:input.login,password:input.password});assert.equal(session.status,200);
 assert.equal((await call('GET','/v1/companies',undefined,session.body.token)).body.length,0);
});


test('company creation retries create one firm and never replay another owner response', async t=>{
 const {app,call,user}=await fixture(t);
 const a=await user('company-owner-a@example.test'),b=await user('company-owner-b@example.test');
 const token=a.token??a; const other=b.token??b;
 const key=randomUUID(),payload={name:'SYNTHETIC RETRY FIRM',currency:'KZT'};
 const results=await Promise.all([call('POST','/v1/companies',payload,token,key),call('POST','/v1/companies',payload,token,key)]);
 assert.equal(results[0].status,201);assert.equal(results[1].status,201);assert.equal(results[0].body.id,results[1].body.id);
 assert.equal((await call('POST','/v1/companies',{...payload,name:'changed'},token,key)).status,409);
 const second=await call('POST','/v1/companies',payload,other,key);assert.equal(second.status,201);assert.notEqual(second.body.id,results[0].body.id);
 assert.equal((await call('GET','/v1/companies',undefined,token)).body.length,1);
 assert.equal((await app.db.prepare("SELECT count(*) AS n FROM audit WHERE action='company.create' AND actor_id<> (SELECT id FROM users WHERE login='owner@example.test')").get()).n,2);
});

test('bank CSV preview, duplicate detection and reviewed posting keep exact project amounts', async t=>{
 const f=await commercialFixture(t);
 const csv='date;reference;debit;credit;description;counterparty\r\n20.10.2026;bank-1;;123,45;"Оплата; услуг";ТЕСТ\r\n2026-10-21;bank-2;23.45;;Комиссия;БАНК';
 const input={csv,walletId:f.wallet.id,name:'SYNTHETIC STATEMENT'};
 const largeCsv='date;reference;debit;credit;description;counterparty\n'+Array.from({length:400},(_,i)=>`2026-10-20;large-${i};0;1;${'d'.repeat(500)};${'p'.repeat(250)}`).join('\n');
 const large=await f.api('POST','/bank-imports/preview',{...input,csv:largeCsv});assert.equal(large.status,200);assert.equal(large.body.items.length,400);
 const preview=await f.api('POST','/bank-imports/preview',input);assert.equal(preview.status,200);assert.equal(preview.body.items[0].amount,12345);assert.equal(preview.body.items[0].description,'Оплата; услуг');
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,0);
 const key=randomUUID(),first=await f.api('POST','/bank-imports',input,key);assert.equal(first.status,200);assert.equal(first.body.inserted,2);
 assert.deepEqual((await f.api('POST','/bank-imports',input,key)).body,first.body);
 assert.equal((await f.api('POST','/bank-imports',input)).body.duplicates,2);
 assert.equal((await f.api('POST','/bank-imports',{...input,csv:csv.replace('123,45','123,46')})).status,409);
 const imported=(await f.api('GET',`/bank-imports/${first.body.id}`)).body;
 const incoming=imported.items.find(r=>r.amount>0),outgoing=imported.items.find(r=>r.amount<0);
 const path=r=>`/bank-imports/${first.body.id}/rows/${r.id}`;
 assert.equal((await f.api('POST',path(incoming)+'/post',{version:1})).status,409);
 const reviewed=(await f.api('PUT',path(incoming),{version:1,classification:'INCOME',projectId:f.project.id})).body;
 assert.equal(reviewed.version,2);
 const posted=await f.api('POST',path(incoming)+'/post',{version:2});assert.equal(posted.status,200);
 assert.equal((await f.api('POST',path(incoming)+'/post',{version:2})).body.journal_id,posted.body.journal_id);
 assert.equal((await f.api('PUT',path(outgoing),{version:1,classification:'INCOME'})).status,400);
 await f.api('PUT',path(outgoing),{version:1,classification:'EXPENSE',projectId:f.project.id});
 assert.equal((await f.api('POST',path(outgoing)+'/post',{version:2})).status,200);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,10000);
 assert.equal((await f.api('GET','/reports/projects')).body.total.netProfit,10000);
 const row=(await f.api('GET',`/bank-imports/${first.body.id}`)).body.items.find(r=>r.id===incoming.id);
 const edited=await f.api('PUT',`/wallets/${f.wallet.id}/entries/${row.wallet_entry_id}`,{amount:12000,type:'INCOME',description:'Исправление',businessDate:'2026-10-20',projectId:f.project.id});
 assert.equal(edited.status,200);assert.equal((await f.api('GET','/wallets')).body.items[0].balance,9655);
 assert.equal((await f.api('GET',`/bank-imports/${first.body.id}`)).body.items.find(r=>r.id===incoming.id).amount,12345,'original statement evidence is preserved');
});

test('bank matching settles the existing service invoice, not a second revenue posting',async t=>{
 const f=await commercialFixture(t);
 const invoice=(await f.api('POST','/commercial-documents',{...f.body,kind:'SALE_INVOICE'})).body;
 await f.api('POST',`/commercial-documents/${invoice.id}/post`,{});
 const imported=(await f.api('POST','/bank-imports',{walletId:f.wallet.id,csv:'date;reference;debit;credit;description\n2026-10-20;payment-1;0;100.00;Оплата счёта'})).body;
 const row=(await f.api('GET',`/bank-imports/${imported.id}`)).body.items[0],path=`/bank-imports/${imported.id}/rows/${row.id}`;
 await f.api('PUT',path,{version:1,classification:'DOCUMENT',documentId:invoice.id});
 assert.equal((await f.api('POST',path+'/post',{version:2})).status,200);
 assert.equal((await f.api('GET',`/commercial-documents/${invoice.id}`)).body.paid,10000);
 assert.equal((await f.api('GET','/reports/projects')).body.total.revenue,0);
 const act=(await f.api('POST',`/commercial-documents/${invoice.id}/act`,{})).body;
 await f.api('POST',`/commercial-documents/${act.id}/post`,{});
 assert.equal((await f.api('GET','/reports/projects')).body.total.revenue,10000);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,10000);
 assert.equal((await f.api('POST','/bank-imports',{walletId:f.wallet.id,csv:'date;reference;debit;credit;description\n2026-10-20;payment-1;0;100.00;Оплата счёта'})).body.inserted,0);
});

test('bank imports reject foreign wallets/projects and malformed money without partial financial writes',async t=>{
 const f=await commercialFixture(t),stranger=await f.user('bank-stranger@example.test');
 const foreign=(await f.call('POST','/v1/companies',{name:'OTHER',currency:'KZT'},stranger.token)).body;
 const bank=(await f.call('POST',`/v1/companies/${foreign.id}/wallets`,{name:'OTHER BANK'},stranger.token,randomUUID())).body;
 const input={walletId:f.wallet.id,csv:'date;reference;debit;credit;description\n2026-10-20;fee-1;1.01;0;Комиссия'};
 assert.equal((await f.api('POST','/bank-imports',{...input,walletId:bank.id})).status,404);
 assert.equal((await f.api('POST','/bank-imports',{...input,csv:input.csv.replace('1.01','1.001')})).status,400);
 assert.equal((await f.api('POST','/bank-imports',{...input,csv:input.csv.replace('1.01;0','1.01;2')})).status,400);
 const imported=(await f.api('POST','/bank-imports',input)).body;
 const row=(await f.api('GET',`/bank-imports/${imported.id}`)).body.items[0],path=`/bank-imports/${imported.id}/rows/${row.id}`;
 await f.api('PUT',path,{version:1,classification:'EXPENSE'});
 assert.equal((await f.api('POST',path+'/post',{version:2})).status,409);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,0);
 assert.equal((await f.api('GET',`/bank-imports/${imported.id}`)).body.items[0].journal_id,null);
 const reader=await f.user('bank-reader@example.test');await f.api('PUT',`/members/${reader.id}`,{permissions:['bank.read']});
 assert.equal((await f.call('POST',f.prefix+'/bank-imports',input,reader.token,randomUUID())).status,403);
 assert.equal((await f.call('GET',f.prefix+`/bank-imports/${imported.id}`,undefined,stranger.token)).status,404);
});

test('dated project reports reconcile opening, turnover, closing and journal drilldown',async t=>{
 const f=await commercialFixture(t);
 const add=async(date,amount,projectId)=>f.api('POST','/accounting/journal',{businessDate:date,projectId,description:'SYNTHETIC REPORT',lines:[{account:'cash',debit:amount},{account:'revenue',credit:amount}]});
 await add('2026-09-30',1000,f.project.id);const included=await add('2026-10-10',2500,f.project.id);await add('2026-10-10',400,null);await add('2026-11-01',900,f.project.id);
 const query=`from=2026-10-01&to=2026-10-31&projectId=${f.project.id}`;
 const trial=await f.api('GET','/accounting/trial-balance?'+query);assert.equal(trial.status,200);
 const cash=trial.body.accounts.find(a=>a.account==='cash');assert.equal(cash.opening,1000);assert.equal(cash.debit,2500);assert.equal(cash.balance,3500);
 assert.equal(trial.body.accounts.reduce((sum,a)=>sum+a.balance,0),0);
 const pl=(await f.api('GET','/reports/profit-loss?'+query)).body;assert.equal(pl.revenue,2500);assert.equal(pl.netProfit,2500);
 const journal=(await f.api('GET','/accounting/journal?'+query+'&account=revenue')).body.items;assert.equal(journal.length,1);assert.equal(journal[0].id,included.body.id);
 assert.equal((await f.api('GET',`/accounting/journal/${included.body.id}`)).body.lines.length,2);
 assert.equal((await f.api('GET','/accounting/trial-balance?from=2026-11-01&to=2026-10-01')).status,400);
 await f.api('POST','/periods/2026-10/close',{reason:'SYNTHETIC CLOSE'});
 assert.equal((await f.api('GET','/periods')).body.items[0].status,'CLOSED');
 assert.equal((await f.api('PUT',`/accounting/journal/${included.body.id}`,{description:'Исправлено после закрытия',expectedRevision:0})).status,200);
 assert.equal((await f.api('PUT',`/accounting/journal/${included.body.id}`,{description:'Устаревшая форма',expectedRevision:0})).status,409);
});


test('single-use recovery expires, revokes old sessions and survives concurrent reset attempts',async t=>{
 const f=await fixture(t);const {issueRecoveryToken}=await import('../src/recovery.js');
 const {hashToken}=await import('../src/security.js');
 const first=await issueRecoveryToken(f.app.db,'owner@example.test');
 const stored=await f.app.db.prepare('SELECT * FROM password_resets').get();assert.equal(stored.token_hash,hashToken(first.token));assert.notEqual(stored.token_hash,first.token);
 const current=await issueRecoveryToken(f.app.db,'owner@example.test');
 assert.equal((await f.call('POST','/v1/auth/reset-password',{token:first.token,password:'SYNTHETIC NEW PASSWORD'})).status,400);
 const results=await Promise.all([f.call('POST','/v1/auth/reset-password',{token:current.token,password:'SYNTHETIC NEW PASSWORD'}),f.call('POST','/v1/auth/reset-password',{token:current.token,password:'SYNTHETIC NEW PASSWORD'})]);
 assert.deepEqual(results.map(r=>r.status).sort(),[200,400]);
 assert.equal((await f.call('GET','/v1/auth/me',undefined,f.owner.token)).status,401);
 assert.equal((await f.call('POST','/v1/auth/login',{login:'owner@example.test',password:'correct-horse-battery'})).status,401);
 assert.equal((await f.call('POST','/v1/auth/login',{login:'owner@example.test',password:'SYNTHETIC NEW PASSWORD'})).status,200);
 const expired=await issueRecoveryToken(f.app.db,'owner@example.test');await f.app.db.prepare('UPDATE password_resets SET expires_at=0').run();
 assert.equal((await f.call('POST','/v1/auth/reset-password',{token:expired.token,password:'SYNTHETIC EXPIRED PASSWORD'})).status,400);
});


test('fixed asset policy uses exact cumulative rounding and edits recalculate project depreciation after close',async t=>{
 const f=await commercialFixture(t),input={name:'SYNTHETIC LAPTOP',inventoryNumber:'SYNTH-001',supplierId:f.supplier.id,scope:'ACCOUNTING',projectId:f.project.id,cost:10001,residual:1000,lifeMonths:3,acquisitionDate:'2026-01-15',depreciationStart:'2026-02',method:'LINEAR_MONTHLY',policyAcknowledged:true};
 const asset=(await f.api('POST','/assets',input)).body;assert.equal(asset.status,'DRAFT');assert.equal((await f.api('GET','/accounting/journal')).body.items.length,0);
 assert.equal((await f.api('POST',`/assets/${asset.id}/activate`,{})).status,200);
 const accrued=(await f.api('POST',`/assets/${asset.id}/depreciation`,{throughMonth:'2026-04'})).body;
 assert.deepEqual(accrued.schedule.map(m=>m.amount),[3000,3001,3000]);assert.equal(accrued.depreciation,9001);assert.equal(accrued.carryingAmount,1000);
 assert.equal((await f.api('GET','/reports/projects')).body.total.expenses,9001);
 await f.api('POST','/periods/2026-02/close',{reason:'SYNTHETIC CLOSE'});
 const other=(await f.api('POST','/projects',{name:'SYNTHETIC SECOND PROJECT'})).body;
 const edited=await f.api('PUT',`/assets/${asset.id}`,{...input,version:accrued.version,cost:16000,residual:1000,projectId:other.id});assert.equal(edited.status,200);assert.equal(edited.body.depreciation,15000);
 const report=(await f.api('GET','/reports/projects')).body;assert.equal(report.total.expenses,15000);assert.equal(report.items.find(p=>p.projectId===f.project.id).expenses,0);assert.equal(report.items.find(p=>p.projectId===other.id).expenses,15000);
 const trial=(await f.api('GET','/accounting/trial-balance')).body.accounts;assert.equal(trial.find(a=>a.account==='fixed_assets').balance,16000);assert.equal(trial.find(a=>a.account==='accumulated_depreciation').balance,-15000);
 const written=await f.api('POST',`/assets/${asset.id}/writeoff`,{businessDate:'2026-03-15',reason:'SYNTHETIC WRITE OFF'});assert.equal(written.status,200);assert.equal(written.body.depreciation,5000);assert.equal(written.body.carryingAmount,0);
 assert.equal((await f.api('GET','/reports/projects')).body.total.expenses,16000);
 assert.equal((await f.api('GET',`/assets/${asset.id}/history`)).body.items.length,4);
 const movements=(await f.api('GET',`/assets/${asset.id}/movements`)).body.items;
 const active=movements.find(m=>m.active);assert.equal((await f.api('GET',`/accounting/journal/${active.journal_id}`)).body.sourceAssetId,asset.id);
 assert.equal((await f.api('PUT',`/accounting/journal/${active.journal_id}`,{businessDate:'2026-09-01'})).status,409);
 assert.equal((await f.api('POST',`/assets/${asset.id}/activate`,{})).status,200);
 assert.equal((await f.api('GET','/reports/projects')).body.total.expenses,15000);
});

test('asset register rejects missing policy, foreign suppliers and duplicate inventory numbers',async t=>{
 const f=await commercialFixture(t),body={name:'SYNTHETIC ASSET',inventoryNumber:'SYNTH-A',supplierId:f.supplier.id,cost:1000,residual:0,lifeMonths:12,acquisitionDate:'2026-10-20',depreciationStart:'2026-11',method:'LINEAR_MONTHLY',policyAcknowledged:true};
 assert.equal((await f.api('POST','/assets',{...body,policyAcknowledged:false})).status,422);
 assert.equal((await f.api('POST','/assets',{...body,supplierId:randomUUID()})).status,404);
 assert.equal((await f.api('POST','/assets',{...body,residual:1001})).status,400);
 const created=await f.api('POST','/assets',body);assert.equal(created.status,200);
 assert.equal((await f.api('POST','/assets',body)).status,409);
 const key=randomUUID();assert.equal((await f.api('POST',`/assets/${created.body.id}/activate`,{},key)).status,200);assert.equal((await f.api('POST',`/assets/${created.body.id}/activate`,{},key)).status,200);
 assert.equal((await f.api('GET','/accounting/journal')).body.items.length,1);
});


test('employee profiles have private permissions, validated dates, exact pay and versioned history',async t=>{
 const f=await commercialFixture(t),body={name:'SYNTHETIC EMPLOYEE',identifier:'000000000001',jobTitle:'SYNTHETIC DEVELOPER',hireDate:'2026-01-01',birthDate:'1990-01-01',grossBase:34567890,projectId:f.project.id,status:'ACTIVE',resident:true,citizenship:'KZ',standardDeductionDeclaration:true,notes:'SYNTHETIC TEST ONLY'};
 const idempotency=randomUUID(),created=await f.api('POST','/employees',body,idempotency);assert.equal(created.status,200);assert.equal(created.body.gross_base,34567890);
 assert.equal((await f.api('POST','/employees',body,idempotency)).body.id,created.body.id);
 assert.equal((await f.api('POST','/employees',body)).status,409);
 assert.equal((await f.api('GET','/employees?q=DEVELOPER')).body.items.length,1);
 const edited=await f.api('PUT',`/employees/${created.body.id}`,{...body,version:1,grossBase:35000000,status:'INACTIVE',terminationDate:'2026-10-20'});assert.equal(edited.status,200);
 assert.equal((await f.api('PUT',`/employees/${created.body.id}`,{...body,version:1})).status,409);
 const history=(await f.api('GET',`/employees/${created.body.id}/history`)).body.items;assert.equal(history.length,1);assert.equal(history[0].snapshot.gross_base,34567890);
 const catalogReader=await f.user('catalog-only@example.test');await f.api('PUT',`/members/${catalogReader.id}`,{permissions:['organization.read','catalog.read']});
 assert.equal((await f.call('GET',f.prefix+'/employees',undefined,catalogReader.token)).status,403);
 assert.equal((await f.api('POST','/resources/employees',{data:{name:'BYPASS'}})).status,404);
 assert.equal((await f.api('POST','/employees',{...body,identifier:'000000000002',birthDate:'2027-01-01'})).status,400);
});

test('owner invitations create scoped members without public registration and never restore revoked access',async t=>{
 const f=await fixture(t),input={login:'invited-reader@example.test',name:'SYNTHETIC INVITED READER',permissions:['reports.read','projects.read']};
 const invitation=await f.api('POST','/invitations',input);assert.equal(invitation.status,200);
 const raw=invitation.body.token,stored=await f.app.db.prepare('SELECT * FROM company_invitations WHERE id=?').get(invitation.body.id);
 assert.notEqual(stored.token_hash,raw);assert.equal((await f.api('GET','/invitations')).body.items[0].token_hash,undefined);
 const preview=await f.call('POST','/v1/auth/invitations/preview',{token:raw});assert.equal(preview.status,200);assert.equal(preview.body.accountExists,false);
 const password=randomUUID(),accepted=await f.call('POST','/v1/auth/invitations/accept',{token:raw,password});assert.equal(accepted.status,200);
 assert.equal((await f.call('POST','/v1/auth/invitations/accept',{token:raw,password})).status,200);
 const login=(await f.call('POST','/v1/auth/login',{login:input.login,password})).body;
 const companies=(await f.call('GET','/v1/companies',undefined,login.token)).body;assert.equal(companies.length,1);assert.equal(companies[0].id,f.company.id);
 assert.equal((await f.call('GET',f.prefix+'/reports/projects',undefined,login.token)).status,200);
 assert.equal((await f.call('GET',f.prefix+'/employees',undefined,login.token)).status,403);
 assert.equal((await f.call('POST','/v1/companies',{name:'FORBIDDEN MEMBER FIRM',currency:'KZT'},login.token)).status,403);
 assert.equal((await f.call('GET','/v1/auth/me',undefined,login.token)).body.memberships[0].companyId,f.company.id);
 assert.ok((await f.api('GET','/members')).body.some(m=>m.userId===login.user.id));
 assert.equal((await f.call('POST',f.prefix+'/invitations',input,login.token)).status,403);
 assert.equal((await f.api('DELETE',`/members/${login.user.id}`)).status,200);
 assert.equal((await f.call('GET','/v1/companies',undefined,login.token)).body.length,0);
 assert.equal((await f.call('POST','/v1/companies',{name:'STILL FORBIDDEN',currency:'KZT'},login.token)).status,403);
 assert.equal((await f.call('POST','/v1/auth/invitations/accept',{token:raw,password})).status,400);
 assert.equal((await f.api('DELETE',`/members/${f.owner.id}`)).status,409);
});

test('inviting an existing account requires its password, preserves credentials and respects revocation',async t=>{
 const f=await fixture(t),existing=await f.user('existing-invite@example.test');
 const create=async()=>f.api('POST','/invitations',{login:'existing-invite@example.test',name:'SYNTHETIC INVITE',permissions:['catalog.read']});
 const first=(await create()).body,second=(await create()).body;
 assert.equal((await f.call('POST','/v1/auth/invitations/preview',{token:first.token})).status,400);
 assert.equal((await f.call('POST','/v1/auth/invitations/preview',{token:second.token})).body.accountExists,true);
 assert.equal((await f.call('POST','/v1/auth/invitations/accept',{token:second.token,password:'SYNTHETIC WRONG PASSWORD'})).status,401);
 assert.equal((await f.call('POST','/v1/auth/invitations/accept',{token:second.token,password:'correct-horse-battery'})).status,200);
 assert.equal((await f.call('GET','/v1/auth/me',undefined,existing.token)).status,200,'existing session/password are preserved');
 const third=(await create()).body;
 await f.api('PUT',`/members/${existing.id}`,{permissions:['reports.read']});
 assert.equal((await f.call('POST','/v1/auth/invitations/accept',{token:third.token,password:'correct-horse-battery'})).status,400);
 const fourth=(await create()).body;await f.api('POST',`/invitations/${fourth.id}/revoke`,{});
 assert.equal((await f.call('POST','/v1/auth/invitations/accept',{token:fourth.token,password:'correct-horse-battery'})).status,400);
});


test('money commands preserve an explicit historical business date and transfer register links',async t=>{
 const f=await fixture(t),source=(await f.api('POST','/wallets',{name:'SYNTHETIC HISTORIC BANK'})).body,target=(await f.api('POST','/wallets',{name:'SYNTHETIC HISTORIC CASH'})).body;
 const income=await f.api('POST',`/wallets/${source.id}/transactions`,{type:'INCOME',amount:10000,description:'SYNTHETIC HISTORIC INCOME',businessDate:'2026-01-10'});assert.equal(income.status,200);
 assert.equal((await f.api('GET','/reports/profit-loss?from=2026-01-01&to=2026-01-31')).body.revenue,10000);
 assert.equal((await f.api('GET','/reports/profit-loss?from=2026-02-01&to=2026-02-28')).body.revenue,0);
 const transfer=await f.api('POST','/wallet-transfers',{sourceWalletId:source.id,targetWalletId:target.id,amount:4000,businessDate:'2026-01-12'});assert.equal(transfer.status,200);
 const rows=await f.app.db.prepare('SELECT e.*,j.business_date FROM wallet_entries e JOIN journal j ON j.id=e.journal_id WHERE e.reference_id=?').all(transfer.body.id);assert.equal(rows.length,2);assert.ok(rows.every(r=>r.business_date==='2026-01-12'));
 const bad=await f.api('POST',`/wallets/${source.id}/transactions`,{type:'EXPENSE',amount:100,description:'INVALID DATE',businessDate:'2026-02-30'});assert.equal(bad.status,400);
 assert.equal((await f.api('GET','/wallets')).body.items.find(w=>w.id===source.id).balance,6000);
});


test('cash transfer correction updates both wallet registers and respects old closed periods',async t=>{
 const f=await fixture(t),a=(await f.api('POST','/wallets',{name:'SYNTHETIC BANK A'})).body,b=(await f.api('POST','/wallets',{name:'SYNTHETIC CASH B'})).body,c=(await f.api('POST','/wallets',{name:'SYNTHETIC CASH C'})).body;
 await f.api('POST',`/wallets/${a.id}/transactions`,{type:'CAPITAL',amount:10000,description:'SYNTHETIC CAPITAL'});
 const transfer=(await f.api('POST','/wallet-transfers',{sourceWalletId:a.id,targetWalletId:b.id,amount:4000,businessDate:'2026-01-10'})).body;
 const old=(await f.api('GET',`/wallet-transfers/${transfer.id}`)).body;assert.equal(old.revision,0);
 await f.api('POST','/periods/2026-01/close',{reason:'SYNTHETIC CLOSE'});
 const update={sourceWalletId:a.id,targetWalletId:c.id,amount:2500,businessDate:'2026-01-20',expectedRevision:0,reason:'SYNTHETIC TRANSFER CORRECTION'};
 const key=randomUUID(),edited=await f.api('PUT',`/wallet-transfers/${transfer.id}`,update,key);assert.equal(edited.status,200);assert.equal(edited.body.revision,1);
 assert.deepEqual((await f.api('PUT',`/wallet-transfers/${transfer.id}`,update,key)).body,edited.body);
 const balances=(await f.api('GET','/wallets')).body.items;assert.equal(balances.find(w=>w.id===a.id).balance,7500);assert.equal(balances.find(w=>w.id===b.id).balance,0);assert.equal(balances.find(w=>w.id===c.id).balance,2500);
 assert.equal((await f.api('PUT',`/wallet-transfers/${transfer.id}`,update)).status,409);
 assert.equal((await f.api('PUT',`/wallet-transfers/${transfer.id}`,{...update,expectedRevision:1,amount:100000})).status,409);
 assert.equal((await f.api('GET',`/wallet-transfers/${transfer.id}`)).body.amount,2500);
 const row=(await f.api('GET',`/wallets/${c.id}/entries`)).body.items[0];assert.equal(row.amount,2500);assert.equal(row.business_date,'2026-01-20');
 assert.equal((await f.api('GET','/reports/profit-loss')).body.netProfit,0);
});

test('cash recount keeps the observed closing snapshot and changes no money',async t=>{
 const f=await fixture(t),wallet=(await f.api('POST','/wallets',{name:'SYNTHETIC CASH'})).body;
 await f.api('POST',`/wallets/${wallet.id}/transactions`,{type:'CAPITAL',amount:10000,description:'SYNTHETIC CAPITAL'});
 const shift=(await f.api('POST','/shifts',{walletId:wallet.id})).body;
 const closed=(await f.api('POST',`/shifts/${shift.id}/close`,{countedAmount:9000})).body;assert.equal(closed.expectedAmount,10000);assert.equal(closed.difference,-1000);
 await f.api('POST',`/wallets/${wallet.id}/transactions`,{type:'INCOME',amount:1000,description:'SYNTHETIC LATER INCOME'});
 const corrected=await f.api('PUT',`/shifts/${shift.id}`,{countedAmount:9500,reason:'SYNTHETIC COUNT CORRECTION'});assert.equal(corrected.status,200);assert.equal(corrected.body.difference,-500);
 const saved=(await f.api('GET','/shifts')).body.items.find(s=>s.id===shift.id);assert.equal(saved.expected_balance,10000);assert.equal(saved.closing,9500);assert.equal(saved.closed_by,f.owner.id);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,11000);
 const other=await f.user('cash-other@example.test');await f.api('PUT',`/members/${other.id}`,{permissions:['shifts.write']});
 assert.equal((await f.call('PUT',f.prefix+`/shifts/${shift.id}`,{countedAmount:0,reason:'FORBIDDEN'},other.token,randomUUID())).status,403);
});

test('explicit wallet balance correction has a dated ledger register entry and leaves profit unchanged',async t=>{
 const f=await fixture(t),wallet=(await f.api('POST','/wallets',{name:'SYNTHETIC CASH'})).body;
 const corrected=await f.api('PUT',`/wallets/${wallet.id}`,{name:'SYNTHETIC RENAMED CASH',balance:3000,businessDate:'2026-01-01',reason:'SYNTHETIC OPENING CORRECTION'});assert.equal(corrected.status,200);
 const entries=(await f.api('GET',`/wallets/${wallet.id}/entries`)).body.items;assert.equal(entries.length,1);const entry=entries[0];assert.equal(entry.kind,'BALANCE_EDIT');assert.equal(entry.amount,3000);assert.equal(entry.business_date,'2026-01-01');assert.ok(entry.journal_id);
 assert.equal((await f.api('GET','/reports/profit-loss?from=2026-01-01&to=2026-01-31')).body.netProfit,0);
});

test('bank reconciliation links existing money without duplicating journals and rejects duplicate or stale matches',async t=>{
 const f=await fixture(t), w=(await f.api('POST','/wallets',{name:'Existing bank'})).body;
 const entry=(await f.api('POST',`/wallets/${w.id}/transactions`,{type:'INCOME',amount:12345,description:'Already entered',businessDate:'2026-10-20'})).body;
 const entries=(await f.api('GET',`/wallets/${w.id}/entries`)).body.items;
 const source=entries.find(e=>e.amount===12345);assert.ok(source);
 const imported=(await f.api('POST','/bank-imports',{walletId:w.id,csv:'date;reference;debit;credit;description\n2026-10-20;existing-1;0;123.45;Existing payment\n2026-10-20;existing-2;0;123.45;Duplicate bank reference'})).body;
 const rows=(await f.api('GET',`/bank-imports/${imported.id}`)).body.items;
 const path=r=>`/bank-imports/${imported.id}/rows/${r.id}`;
 const candidates=await f.api('GET',path(rows[0])+'/candidates');assert.equal(candidates.status,200);assert.equal(candidates.body.items[0].id,source.id);
 const before=(await f.api('GET','/accounting/journal')).body.items.length;
 const review=await f.api('PUT',path(rows[0]),{version:1,classification:'EXISTING',entryId:source.id});assert.equal(review.status,200);
 assert.equal((await f.api('POST',path(rows[0])+'/post',{version:2})).status,200);
 assert.equal((await f.api('POST',path(rows[0])+'/post',{version:2})).status,200);
 assert.equal((await f.api('GET','/accounting/journal')).body.items.length,before);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,12345);
 assert.equal((await f.api('GET',path(rows[1])+'/candidates')).body.items.length,0);
 assert.equal((await f.api('PUT',path(rows[1]),{version:1,classification:'EXISTING',entryId:source.id})).status,409);
 const wrong=(await f.api('POST',`/wallets/${w.id}/transactions`,{type:'INCOME',amount:100,description:'Other date',businessDate:'2026-10-19'})).body;
 const wrongEntry=(await f.api('GET',`/wallets/${w.id}/entries`)).body.items.find(e=>e.amount===100);
 assert.equal((await f.api('PUT',path(rows[1]),{version:1,classification:'EXISTING',entryId:wrongEntry.id})).status,409);
 assert.equal(entry.amount,12345);assert.equal(wrong.amount,100);
 const another=(await f.api('POST','/bank-imports',{walletId:w.id,csv:'date;reference;debit;credit;description\n2026-10-19;stale-entry;0;1.00;Stale test'})).body;
 const stale=(await f.api('GET',`/bank-imports/${another.id}`)).body.items[0],stalePath=`/bank-imports/${another.id}/rows/${stale.id}`;
 assert.equal((await f.api('PUT',stalePath,{version:1,classification:'EXISTING',entryId:wrongEntry.id})).status,200);
 await f.api('PUT',`/wallets/${w.id}/entries/${wrongEntry.id}`,{type:'INCOME',amount:101,description:'Changed before reconciliation',businessDate:'2026-10-19'});
 assert.equal((await f.api('POST',stalePath+'/post',{version:2})).status,409);
 assert.equal((await f.api('GET',`/bank-imports/${another.id}`)).body.items[0].journal_id,null);
});

test('counterparty service statement reconciles advances, recognition, corrections and payment void/restore without duplicates',async t=>{
 const f=await commercialFixture(t),path=`/counterparties/clients/${f.client.id}/service-statement`;
 const invoice=(await f.api('POST','/commercial-documents',{...f.body,kind:'SALE_INVOICE'})).body;
 await f.api('POST',`/commercial-documents/${invoice.id}/post`,{});
 const paid=(await f.api('POST',`/commercial-documents/${invoice.id}/payments`,{walletId:f.wallet.id,amount:4000,businessDate:'2026-10-19'})).body;
 let r=await f.api('GET',path);assert.equal(r.status,200);assert.equal(r.body.accounts.find(a=>a.account==='customer_advances').closing,-4000);assert.equal(r.body.accounts.find(a=>a.account==='receivables').closing,0);
 const act=(await f.api('POST',`/commercial-documents/${invoice.id}/act`,{})).body;
 await f.api('POST',`/commercial-documents/${act.id}/post`,{});
 r=await f.api('GET',path+'?from=2026-10-20&to=2026-10-20');assert.equal(r.status,200);
 assert.equal(r.body.accounts.find(a=>a.account==='customer_advances').opening,-4000);assert.equal(r.body.accounts.find(a=>a.account==='customer_advances').closing,0);assert.equal(r.body.accounts.find(a=>a.account==='receivables').closing,6000);
 const doc=(await f.api('GET',`/commercial-documents/${act.id}`)).body;
 const revised=await f.api('PUT',`/commercial-documents/${act.id}`,{...f.body,version:doc.version,items:[{description:'Corrected service',quantity:'1.000',unitPrice:3000}],reason:'SYNTHETIC COUNTERPARTY CORRECTION'});assert.equal(revised.status,200);
 r=await f.api('GET',path);assert.equal(r.body.accounts.find(a=>a.account==='receivables').closing,0);assert.equal(r.body.accounts.find(a=>a.account==='customer_advances').closing,-1000);
 assert.equal((await f.api('POST',`/commercial-documents/${invoice.id}/payments/${paid.id}/void`,{})).status,200);
 r=await f.api('GET',path);assert.equal(r.body.accounts.find(a=>a.account==='receivables').closing,3000);assert.equal(r.body.accounts.find(a=>a.account==='customer_advances').closing,0);
 assert.equal((await f.api('POST',`/commercial-documents/${invoice.id}/payments/${paid.id}/restore`,{})).status,200);
 r=await f.api('GET',path);assert.equal(r.body.accounts.find(a=>a.account==='receivables').closing,0);assert.equal(r.body.accounts.find(a=>a.account==='customer_advances').closing,-1000);
 const first=await f.api('GET',path+'?limit=1');assert.equal(first.body.items.length,1);assert.ok(first.body.nextCursor);
 const second=await f.api('GET',path+'?limit=1&after='+first.body.nextCursor);assert.notEqual(second.body.items[0].id,first.body.items[0].id);
 assert.deepEqual(first.body.accounts,r.body.accounts,'pagination does not change totals');
 assert.ok((await f.api('GET',path+'?projectId=unassigned')).body.accounts.every(a=>a.closing===0));
 assert.equal((await f.api('GET',`/counterparties/suppliers/${f.client.id}/service-statement`)).status,404);
 assert.equal((await f.api('GET',path+'?scope=BOTH')).status,400);
 const other=await f.user('statement-other@example.test');assert.equal((await f.call('GET',f.prefix+path,undefined,other.token)).status,404);
 const list=await f.api('GET','/commercial-documents?counterpartyId='+f.supplier.id);assert.equal(list.body.summary.count,0);
});

test('dated goods payments use real wallets and reclassify advances after closed-period project and date corrections',async t=>{
 const f=await fixture(t),refs=await f.catalog();
 await f.api('POST','/inventory/receipts',{...refs,quantity:10,unitCost:100,businessDate:'2026-01-01'});
 const wallet=(await f.api('POST','/wallets',{name:'GOODS BANK'})).body;
 const a=(await f.api('POST','/projects',{name:'Goods A'})).body,b=(await f.api('POST','/projects',{name:'Goods B'})).body;
 const order=(await f.api('POST','/orders',{businessDate:'2026-01-10',projectId:a.id,items:[{...refs,quantity:4,unitPrice:200}]})).body;
 await f.api('POST',`/orders/${order.id}/reserve`,{});assert.equal((await f.api('POST',`/orders/${order.id}/ship`,{})).status,200);
 const key=randomUUID(),payment=await f.api('POST',`/orders/${order.id}/payments`,{amount:800,walletId:wallet.id,businessDate:'2026-01-05'},key);assert.equal(payment.status,200);
 assert.deepEqual((await f.api('POST',`/orders/${order.id}/payments`,{amount:800,walletId:wallet.id,businessDate:'2026-01-05'},key)).body,payment.body);
 let trial=(await f.api('GET','/accounting/trial-balance?to=2026-01-09')).body.accounts;
 assert.equal(trial.find(a=>a.account==='customer_advances').balance,-800);assert.equal(trial.find(a=>a.account==='receivables')?.balance??0,0);
 trial=(await f.api('GET','/accounting/trial-balance?to=2026-01-10')).body.accounts;assert.equal(trial.find(a=>a.account==='customer_advances').balance,0);assert.equal(trial.find(a=>a.account==='receivables').balance,0);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,800);
 await f.api('POST','/periods/2026-01/close',{});
 const revised=await f.api('PUT',`/orders/${order.id}`,{expectedRevision:0,projectId:b.id,businessDate:'2026-01-20',items:[{...refs,quantity:3,unitPrice:200}],reason:'SYNTHETIC GOODS CORRECTION'});assert.equal(revised.status,200);assert.equal(revised.body.customerCredit,200);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,800);
 assert.equal((await f.api('GET',`/reports/projects?projectId=${a.id}`)).body.items[0].netProfit,0);assert.equal((await f.api('GET',`/reports/projects?projectId=${b.id}`)).body.items[0].netProfit,300);
 assert.equal((await f.api('GET','/reports/profit-loss?from=2026-01-10&to=2026-01-19')).body.revenue,0);
 trial=(await f.api('GET','/accounting/trial-balance')).body.accounts;assert.equal(trial.find(a=>a.account==='cash')?.balance??0,0);assert.equal(trial.find(a=>a.account==='customer_advances').balance,-200);assert.equal(trial.find(a=>a.account==='receivables').balance,0);
 const details=(await f.api('GET',`/orders/${order.id}`)).body;assert.equal(details.paid,800);assert.equal(details.customerCredit,200);assert.equal(details.revision,1);
 const records=(await f.api('GET',`/wallets/${wallet.id}/entries`)).body.items;assert.equal(records.length,1);assert.equal(records[0].amount,800);assert.equal(records[0].project_id,b.id);
 assert.equal((await f.api('GET',`/orders/${order.id}/payments`)).body.items[0].business_date,'2026-01-05');
 assert.equal((await f.api('PUT',`/orders/${order.id}`,{expectedRevision:0,items:[{...refs,quantity:2,unitPrice:200}]})).status,409);
 assert.equal((await f.api('PUT',`/orders/${order.id}`,{scope:'MANAGEMENT',items:[{...refs,quantity:3,unitPrice:200}]})).status,400);
 assert.equal((await f.api('GET',`/orders/${order.id}`)).body.revision,1);
});

test('goods VAT uses exact per-line rounding and corrections split revenue and VAT without changing paid cash',async t=>{
 const f=await commercialFixture(t,{vat:true}),refs=await f.catalog();
 const other=(await f.api('POST','/resources/nomenklatura',{data:{name:'Second product'}})).body;
 await f.api('POST','/inventory/receipts',{...refs,quantity:10,unitCost:10,businessDate:'2026-01-01'});
 await f.api('POST','/inventory/receipts',{...refs,productId:other.id,quantity:10,unitCost:10,businessDate:'2026-01-01'});
 const input={counterpartyId:f.client.id,projectId:f.project.id,businessDate:'2026-01-10',vatBasisPoints:1600,items:[{...refs,quantity:3,unitPrice:101},{...refs,productId:other.id,quantity:1,unitPrice:101}]};
 const created=await f.api('POST','/orders',input);assert.equal(created.status,200);assert.equal(created.body.number,'ТН-2026-0001');assert.equal(created.body.net,404);assert.equal(created.body.vat,64);assert.equal(created.body.total,468);assert.equal(created.body.counterparty.name,'SYNTHETIC CLIENT');
 const id=created.body.id;await f.api('POST',`/orders/${id}/reserve`,{});await f.api('POST',`/orders/${id}/ship`,{});await f.api('POST',`/orders/${id}/payments`,{amount:468,walletId:f.wallet.id,businessDate:'2026-01-11'});
 const edited=await f.api('PUT',`/orders/${id}`,{...input,items:[{...refs,quantity:3,unitPrice:102},{...refs,productId:other.id,quantity:1,unitPrice:101}]});assert.equal(edited.status,200);assert.equal(edited.body.number,created.body.number);assert.equal(edited.body.total,472);assert.equal(edited.body.vat,65);assert.equal(edited.body.status,'SHIPPED');
 const trial=(await f.api('GET','/accounting/trial-balance')).body.accounts;assert.equal(trial.find(a=>a.account==='revenue').balance,-407);assert.equal(trial.find(a=>a.account==='vat_payable').balance,-65);assert.equal(trial.find(a=>a.account==='receivables').balance,4);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,468);
 assert.equal((await f.api('POST','/orders',{...input,vatBasisPoints:0})).status,422);
 assert.equal((await f.api('POST','/orders',{...input,businessDate:'2025-12-31'})).status,422);
});

test('goods payment correction, void and restore preserve actual wallets, advance dates and audit versions',async t=>{
 const f=await fixture(t),refs=await f.catalog();await f.api('POST','/inventory/receipts',{...refs,quantity:10,unitCost:100});
 const a=(await f.api('POST','/wallets',{name:'Goods bank A'})).body,b=(await f.api('POST','/wallets',{name:'Goods bank B'})).body;
 const order=(await f.api('POST','/orders',{businessDate:'2026-01-10',items:[{...refs,quantity:4,unitPrice:200}]})).body;
 await f.api('POST',`/orders/${order.id}/reserve`,{});await f.api('POST',`/orders/${order.id}/ship`,{});
 const payment=(await f.api('POST',`/orders/${order.id}/payments`,{walletId:a.id,amount:800,businessDate:'2026-01-11'})).body;
 const path=`/orders/${order.id}/payments/${payment.id}`;
 await f.api('POST',`/wallets/${a.id}/transactions`,{type:'EXPENSE',amount:200,description:'Already spent'});
 const correction={version:1,walletId:b.id,amount:600,businessDate:'2026-01-05',reason:'SYNTHETIC GOODS PAYMENT EDIT'};
 assert.equal((await f.api('PUT',path,correction)).status,409,'moving spent cash must roll back both wallet registers');
 assert.equal((await f.api('GET',`/orders/${order.id}/payments`)).body.items[0].version,1);
 await f.api('POST',`/wallets/${a.id}/transactions`,{type:'CAPITAL',amount:200,description:'Funds replacing spent cash'});
 const edited=await f.api('PUT',path,correction);assert.equal(edited.status,200);assert.equal(edited.body.version,2);assert.equal(edited.body.outstanding,200);
 let wallets=(await f.api('GET','/wallets')).body.items;assert.equal(wallets.find(w=>w.id===a.id).balance,0);assert.equal(wallets.find(w=>w.id===b.id).balance,600);
 let trial=(await f.api('GET','/accounting/trial-balance?to=2026-01-09')).body.accounts;assert.equal(trial.find(a=>a.account==='customer_advances').balance,-600);
 assert.equal((await f.api('POST',path+'/void',{version:2})).status,200);assert.equal((await f.api('GET',`/orders/${order.id}`)).body.paid,0);assert.equal((await f.api('GET','/wallets')).body.items.find(w=>w.id===b.id).balance,0);
 assert.equal((await f.api('POST',path+'/restore',{version:3})).status,200);assert.equal((await f.api('GET',`/orders/${order.id}`)).body.paid,600);
 const overpaid=await f.api('PUT',path,{...correction,version:4,amount:1000});assert.equal(overpaid.status,200);assert.equal(overpaid.body.customerCredit,200);
 trial=(await f.api('GET','/accounting/trial-balance')).body.accounts;assert.equal(trial.find(a=>a.account==='receivables').balance,0);assert.equal(trial.find(a=>a.account==='customer_advances').balance,-200);
 assert.equal((await f.api('GET','/wallets')).body.items.find(w=>w.id===b.id).balance,1000);
 const entry=(await f.api('GET',`/wallets/${b.id}/entries`)).body.items.find(e=>e.kind==='ORDER_PAYMENT');
 const journal=(await f.api('GET',`/accounting/journal/${entry.journal_id}`)).body;assert.equal(journal.sourceOrderId,order.id);
 assert.equal((await f.api('PUT',`/accounting/journal/${entry.journal_id}`,{lines:[{account:'cash',debit:1},{account:'capital',credit:1}]})).status,409);
 assert.equal((await f.api('PUT',path,{...correction,version:1})).status,409);
});

async function payrollFixture(t){
 const f=await fixture(t);
 await f.api('PUT','/settings',{version:0,legalName:'SYNTHETIC PAYROLL FIRM',identifier:'000000000000',legalForm:'TOO',taxRegime:'GENERAL',vatRegistered:false});
 const employee=(await f.api('POST','/employees',{name:'SYNTHETIC PAYROLL EMPLOYEE',identifier:'000000000001',jobTitle:'SYNTHETIC JOB',hireDate:'2025-01-01',birthDate:'1990-01-01',grossBase:30000000,status:'ACTIVE',resident:true,citizenship:'KZ',standardDeductionDeclaration:true})).body;
 const a=(await f.api('POST','/projects',{name:'Payroll A'})).body,b=(await f.api('POST','/projects',{name:'Payroll B'})).body;
 const body={employeeId:employee.id,month:'2026-01',gross:30000000,sex:'M',category:'ORDINARY_CASH_SALARY',singleEmployer:true,policyAcknowledged:true,projectId:a.id};
 return {...f,employee,a,b,body};
}
test('payroll posts exact employer cost and changes paid closed-period wages without inventing a refund',async t=>{
 const f=await payrollFixture(t);
 const preview=await f.api('POST','/payroll/preview',f.body);assert.equal(preview.status,200);assert.equal(preview.body.calculation.net,25057500);assert.equal(preview.body.calculation.totalCost,34884000);
 const draft=(await f.api('POST','/payroll',f.body)).body;assert.equal(draft.status,'DRAFT');assert.equal((await f.api('GET','/accounting/journal')).body.items.length,0);
 const posted=await f.api('POST',`/payroll/${draft.id}/post`,{version:draft.version});assert.equal(posted.status,200);assert.equal(posted.body.status,'POSTED');
 const wallet=(await f.api('POST','/wallets',{name:'Salary bank'})).body;await f.api('POST',`/wallets/${wallet.id}/transactions`,{type:'CAPITAL',amount:100000000,description:'Payroll funds'});
 const paid=await f.api('POST',`/payroll/${draft.id}/payments`,{walletId:wallet.id,amount:25057500,businessDate:'2026-01-15'});assert.equal(paid.status,200);
 const balance=(await f.api('GET','/wallets')).body.items[0].balance;assert.equal(balance,74942500);
 await f.api('POST','/periods/2026-01/close',{});
 const current=(await f.api('GET',`/payroll/${draft.id}`)).body;
 const corrected=await f.api('PUT',`/payroll/${draft.id}`,{...f.body,version:current.version,gross:20000000,projectId:f.b.id,reason:'SYNTHETIC PAYROLL CORRECTION'});assert.equal(corrected.status,200);assert.equal(corrected.body.data.calculation.net,17137500);assert.equal(corrected.body.employeeAdvance,7920000);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,balance);
 const report=(await f.api('GET','/reports/projects')).body.items;assert.equal(report.find(p=>p.projectId===f.a.id).expenses,0);assert.equal(report.find(p=>p.projectId===f.b.id).expenses,23256000);
 const trial=(await f.api('GET','/accounting/trial-balance')).body.accounts;assert.equal(trial.find(a=>a.account==='payroll_advances').balance,7920000);assert.equal(trial.find(a=>a.account==='payroll_payable').balance,0);
});
test('editing an earlier payroll rebuilds later cumulative deductions and keeps later cash unchanged',async t=>{
 const f=await payrollFixture(t),jan=(await f.api('POST','/payroll',{...f.body,gross:1000000})).body;
 assert.equal((await f.api('POST',`/payroll/${jan.id}/post`,{version:jan.version})).status,200);
 const feb=(await f.api('POST','/payroll',{...f.body,month:'2026-02'})).body;
 const posted=(await f.api('POST',`/payroll/${feb.id}/post`,{version:feb.version})).body;assert.equal(posted.data.calculation.ipn,133000);
 const wallet=(await f.api('POST','/wallets',{name:'February salary bank'})).body;await f.api('POST',`/wallets/${wallet.id}/transactions`,{type:'CAPITAL',amount:100000000,description:'Payroll funds'});
 await f.api('POST',`/payroll/${feb.id}/payments`,{walletId:wallet.id,amount:posted.data.calculation.net,businessDate:'2026-03-05'});
 const balance=(await f.api('GET','/wallets')).body.items[0].balance,oldJanuary=(await f.api('GET',`/payroll/${jan.id}`)).body;
 assert.equal((await f.api('PUT',`/payroll/${jan.id}`,{...f.body,version:oldJanuary.version,reason:'SYNTHETIC EARLIER MONTH'})).status,200);
 const changed=(await f.api('GET',`/payroll/${feb.id}`)).body;assert.equal(changed.data.calculation.ipn,1342500);assert.equal(changed.employeeAdvance,1209500);assert.ok(changed.version>posted.version);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,balance);
});
test('payroll requires explicit opening context and private permissions, and never assumes missing months are zero',async t=>{
 const f=await payrollFixture(t),body={...f.body,month:'2026-10'};
 assert.equal((await f.api('POST','/payroll/preview',body)).body.error,'payroll_opening_or_missing_month_required');
 const opening=await f.api('PUT',`/payroll/openings/${f.employee.id}`,{version:0,throughMonth:'2026-09',taxableBase:120825000,ipn:12082500,basicUsed:116775000,basicCarry:0,opvBase:270000000,confirmed:true,sourceNote:'SYNTHETIC nine prior months same employer'});assert.equal(opening.status,200);
 const preview=await f.api('POST','/payroll/preview',body);assert.equal(preview.status,200);assert.equal(preview.body.calculation.ipn,1342500);
 const record=(await f.api('POST','/payroll',body)).body;assert.ok(record.id);
 assert.equal((await f.api('PUT',`/payroll/openings/${f.employee.id}`,{version:1,throughMonth:'2026-10',taxableBase:0,ipn:0,basicUsed:0,basicCarry:0,opvBase:0,confirmed:true,sourceNote:'Overlap'})).status,409);
 const reader=await f.user('payroll-reader@example.test');await f.api('PUT',`/members/${reader.id}`,{permissions:['organization.read','employees.read','reports.read']});
 assert.equal((await f.call('GET',f.prefix+'/payroll',undefined,reader.token)).status,403);
 assert.equal((await f.call('POST',f.prefix+'/payroll/preview',body,reader.token)).status,403);
});

test('payroll cancellation and restoration rebuild later deductions while preserving actual payments',async t=>{
 const f=await payrollFixture(t),jan=(await f.api('POST','/payroll',f.body)).body;await f.api('POST',`/payroll/${jan.id}/post`,{version:jan.version});
 const feb=(await f.api('POST','/payroll',{...f.body,month:'2026-02'})).body;await f.api('POST',`/payroll/${feb.id}/post`,{version:feb.version});
 const wallet=(await f.api('POST','/wallets',{name:'Salary cash'})).body;await f.api('POST',`/wallets/${wallet.id}/transactions`,{type:'CAPITAL',amount:100000000,description:'Salary funds'});
 await f.api('POST',`/payroll/${jan.id}/payments`,{walletId:wallet.id,amount:25057500,businessDate:'2026-02-05'});await f.api('POST',`/payroll/${feb.id}/payments`,{walletId:wallet.id,amount:25057500,businessDate:'2026-03-05'});
 const balance=(await f.api('GET','/wallets')).body.items[0].balance,current=(await f.api('GET',`/payroll/${jan.id}`)).body;
 const cancelled=await f.api('POST',`/payroll/${jan.id}/cancel`,{version:current.version});assert.equal(cancelled.status,200);assert.equal(cancelled.body.data.calculation.gross,0);assert.equal(cancelled.body.employeeAdvance,25057500);
 const recalculated=(await f.api('GET',`/payroll/${feb.id}`)).body;assert.equal(recalculated.data.calculation.ipn,45000);assert.equal(recalculated.outstanding,1297500);
 const restored=await f.api('POST',`/payroll/${jan.id}/restore`,{version:cancelled.body.version});assert.equal(restored.status,200);assert.equal(restored.body.data.calculation.gross,30000000);assert.equal(restored.body.employeeAdvance,0);
 assert.equal((await f.api('GET',`/payroll/${feb.id}`)).body.data.calculation.ipn,1342500);assert.equal((await f.api('GET','/wallets')).body.items[0].balance,balance);
});
test('salary payment edits, cancellation and restore update a real wallet and protect the source journal',async t=>{
 const f=await payrollFixture(t),draft=(await f.api('POST','/payroll',f.body)).body;await f.api('POST',`/payroll/${draft.id}/post`,{version:draft.version});
 const wallet=(await f.api('POST','/wallets',{name:'Salary corrections'})).body;await f.api('POST',`/wallets/${wallet.id}/transactions`,{type:'CAPITAL',amount:100000000,description:'Salary funds'});
 const paid=(await f.api('POST',`/payroll/${draft.id}/payments`,{walletId:wallet.id,amount:25057500,businessDate:'2026-02-05'})).body,path=`/payroll/${draft.id}/payments/${paid.id}`;
 const edited=await f.api('PUT',path,{version:1,walletId:wallet.id,amount:24000000,businessDate:'2026-01-20',reason:'SYNTHETIC SALARY PAYMENT'});assert.equal(edited.status,200);assert.equal(edited.body.payroll.outstanding,1057500);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,76000000);
 const voided=await f.api('POST',path+'/void',{version:2});assert.equal(voided.status,200);assert.equal(voided.body.payroll.paid,0);assert.equal((await f.api('GET','/wallets')).body.items[0].balance,100000000);
 assert.equal((await f.api('POST',path+'/restore',{version:3})).status,200);assert.equal((await f.api('GET','/wallets')).body.items[0].balance,76000000);
 const source=(await f.api('GET',`/payroll/${draft.id}/payments`)).body.items[0],journal=(await f.api('GET',`/accounting/journal/${source.journal_id}`)).body;assert.equal(journal.sourcePayrollId,draft.id);
 assert.equal((await f.api('PUT',`/accounting/journal/${source.journal_id}`,{lines:[{account:'cash',debit:1},{account:'capital',credit:1}]})).status,409);
 assert.equal((await f.api('GET',path+'/history')).body.items.length,3);
});

test('payroll drafts reject changed cumulative context and require a fresh calculation before posting',async t=>{
 const f=await payrollFixture(t),path=`/payroll/openings/${f.employee.id}`,opening={version:0,throughMonth:'2026-09',taxableBase:120825000,ipn:12082500,basicUsed:116775000,basicCarry:0,opvBase:270000000,confirmed:true,sourceNote:'SYNTHETIC INITIAL CONTEXT'};
 assert.equal((await f.api('PUT',path,opening)).status,200);
 const body={...f.body,month:'2026-10'},draft=(await f.api('POST','/payroll',body)).body;
 assert.equal((await f.api('PUT',path,{...opening,version:1,taxableBase:120825100,ipn:12082510,basicUsed:116774900,basicCarry:100,sourceNote:'SYNTHETIC CORRECTED CONTEXT'})).status,200);
 const stale=await f.api('POST',`/payroll/${draft.id}/post`,{version:draft.version});assert.equal(stale.status,409);assert.equal(stale.body.error,'payroll_calculation_changed');
 assert.equal((await f.api('GET','/accounting/journal')).body.items.length,0);
 const updated=await f.api('PUT',`/payroll/${draft.id}`,{...body,version:draft.version,reason:'Recalculate changed context'});assert.equal(updated.status,200);assert.equal(updated.body.data.calculation.net,25057510);
 assert.equal((await f.api('POST',`/payroll/${draft.id}/post`,{version:updated.body.version})).status,200);
});
test('payroll save checks the company and employee revisions reviewed in preview',async t=>{
 const f=await payrollFixture(t),preview=(await f.api('POST','/payroll/preview',f.body)).body;
 assert.equal(preview.input.company.version,1);assert.equal(preview.input.employee.version,1);
 await f.api('PUT','/settings',{version:1,legalName:'SYNTHETIC CHANGED COMPANY',identifier:'000000000000',legalForm:'TOO',taxRegime:'GENERAL',vatRegistered:false});
 const stale=await f.api('POST','/payroll',{...f.body,expectedCompanyVersion:preview.input.company.version,expectedEmployeeVersion:preview.input.employee.version});assert.equal(stale.status,409);
 assert.equal((await f.api('GET','/payroll')).body.items.length,0);
 const current=(await f.api('POST','/payroll/preview',f.body)).body;
 assert.equal((await f.api('POST','/payroll',{...f.body,expectedCompanyVersion:current.input.company.version,expectedEmployeeVersion:current.input.employee.version})).status,200);
});

test('numeric KZ income, returns, costs and expenses reconcile across project and firm reports after historical correction', async t => {
 const f=await fixture(t);
 const project=(await f.api('POST','/projects',{name:'Dynamic numeric project'})).body;
 const entry=async(projectId,lines,date='2026-01-15',scope='ACCOUNTING')=>{
  const response=await f.api('POST','/accounting/journal',{description:'Numeric chart entry',businessDate:date,scope,projectId,lines});
  assert.equal(response.status,200,JSON.stringify(response.body));return response.body;
 };
 await entry(project.id,[{account:'1210',debit:10000},{account:'6010',credit:10000}]);
 await entry(project.id,[{account:'6020',debit:1000},{account:'1210',credit:1000}]);
 await entry(project.id,[{account:'6030',debit:500},{account:'1210',credit:500}]);
 await entry(project.id,[{account:'7010',debit:3000},{account:'1330',credit:3000}]);
 const expense=await entry(project.id,[{account:'7210',debit:2000},{account:'3310',credit:2000}]);
 await entry(null,[{account:'7310',debit:400},{account:'3380',credit:400}]);
 await entry(null,[{account:'1270',debit:200},{account:'6110',credit:200}],undefined,'BOTH');
 await entry(null,[{account:'receivables',debit:300},{account:'revenue',credit:300}]);
 await entry(project.id,[{account:'1210',debit:999},{account:'6010',credit:999}],'2026-02-01');
 await entry(project.id,[{account:'7210',debit:777},{account:'3310',credit:777}],undefined,'MANAGEMENT');
 const query='?from=2026-01-01&to=2026-01-31';
 let report=(await f.api('GET','/reports/projects'+query)).body;
 assert.deepEqual(report.total,{revenue:9000,salesRevenue:8800,otherIncome:200,cogs:3000,expenses:2400,costs:5400,grossProfit:5800,netProfit:3600});
 assert.equal(report.items.find(p=>p.projectId===project.id).netProfit,3500);
 const selectedReport=(await f.api('GET','/reports/projects'+query+'&projectId='+project.id)).body;
 assert.deepEqual(selectedReport.selectionTotal,{revenue:8500,salesRevenue:8500,otherIncome:0,cogs:3000,expenses:2000,costs:5000,grossProfit:5500,netProfit:3500});
 assert.equal(selectedReport.total.revenue,9000);
 assert.equal(report.items.find(p=>p.projectId===null).netProfit,100);
 const pl=(await f.api('GET','/reports/profit-loss'+query)).body;
 for(const [key,value] of Object.entries(report.total))assert.equal(pl[key],value);
 assert.equal((await f.api('GET','/reports/profit-loss'+query+'&projectId='+project.id)).body.netProfit,3500);
 const close=await f.api('POST','/periods/2026-01/close',{reason:'Owner reviewed January'});assert.equal(close.status,200);
 const old=(await f.api('GET','/accounting/journal/'+expense.id)).body;
 const edited=await f.api('PUT','/accounting/journal/'+expense.id,{expectedRevision:old.revision,description:'Correct numeric expense',businessDate:'2026-01-15',scope:'ACCOUNTING',projectId:project.id,lines:[{account:'7210',debit:1500},{account:'3310',credit:1500}]});
 assert.equal(edited.status,200,JSON.stringify(edited.body));
 report=(await f.api('GET','/reports/projects'+query)).body;
 assert.equal(report.total.netProfit,4100);
 assert.equal(report.items.find(p=>p.projectId===project.id).netProfit,4000);
 const trial=(await f.api('GET','/accounting/trial-balance'+query)).body;
 assert.equal(trial.accounts.find(a=>a.account==='7210').balance,1500);
});

test('company tax tasks retain manually confirmed dates, idempotency and history without creating money',async t=>{
 const f=await fixture(t),body={title:'Pay checked tax',dueDate:'2026-01-25',status:'OPEN',category:'TAX',notes:'SYNTHETIC NOTE',source:'Owner checked actual applicable deadline',dueDateConfirmed:true};
 assert.equal((await f.api('POST','/tax-calendar',{...body,dueDateConfirmed:false})).status,422);
 assert.equal((await f.api('POST','/tax-calendar',{...body,dueDate:'2026-02-30'})).status,400);
 const key=randomUUID(),created=await f.api('POST','/tax-calendar',body,key);assert.equal(created.status,200,JSON.stringify(created.body));
 assert.deepEqual((await f.api('POST','/tax-calendar',body,key)).body,created.body);
 assert.equal((await f.api('POST','/tax-calendar',{...body,title:'Changed intent'},key)).status,409);
 assert.equal((await f.api('POST','/periods/2026-01/close',{reason:'Reviewed'})).status,200);
 const edit=await f.api('PUT','/tax-calendar/'+created.body.id,{...body,title:'Corrected task',dueDate:'2026-01-26',status:'DONE',version:1});assert.equal(edit.status,200);assert.equal(edit.body.version,2);
 assert.equal((await f.api('PUT','/tax-calendar/'+created.body.id,{...body,version:1})).status,409);
 const history=(await f.api('GET',`/tax-calendar/${created.body.id}/history`)).body.items;assert.equal(history.length,1);assert.equal(history[0].snapshot.due_date,'2026-01-25');
 const report=(await f.api('GET','/tax-calendar?from=2026-01-01&to=2026-01-31')).body;assert.equal(report.items.length,1);assert.equal(report.counts.done,1);assert.equal(report.companyWide,true);assert.equal(report.automaticOfficialDeadlines,false);
 assert.deepEqual((await f.api('GET','/accounting/journal')).body.items,[]);
 const outsider=await f.user('tax-outsider@example.test');assert.equal((await f.call('GET',f.prefix+'/tax-calendar',null,outsider.token)).status,404);
 const other=(await f.call('POST','/v1/companies',{name:'Other tax company',currency:'KZT'},outsider.token)).body;
 assert.equal((await f.call('PUT',`/v1/companies/${other.id}/tax-calendar/${created.body.id}`,{...body,version:2},outsider.token,randomUUID())).status,404);
 await f.app.db.prepare("INSERT INTO memberships(company_id,user_id,role,permissions) VALUES(?,?,'member',?)").run(f.company.id,outsider.id,JSON.stringify(['tax-calendar.read']));
 assert.equal((await f.call('GET',f.prefix+'/tax-calendar',null,outsider.token)).status,200);
 assert.equal((await f.call('PUT',f.prefix+'/tax-calendar/'+created.body.id,{...body,version:2},outsider.token,randomUUID())).status,403);
 assert.equal((await f.call('GET',f.prefix+'/tax-calendar/preparation/2026-01',null,outsider.token)).status,403,'task readers do not implicitly gain company profile access');
});

test('tax preparation saves actual confirmations and invalidates profile approval after company settings change',async t=>{
 const f=await fixture(t),path='/tax-calendar/preparation/2026-01';
 const initial=(await f.api('GET',path)).body;assert.equal(initial.version,0);assert.equal(initial.ready,false);
 const checks={version:0,settingsVersion:null,profileChecked:true,documentsChecked:true,controlsChecked:true};
 assert.equal((await f.api('PUT',path,checks)).status,422);
 const settings={version:0,legalName:'SYNTHETIC TAX PROFILE',identifier:'000000000000',legalForm:'TOO',taxRegime:'GENERAL',vatRegistered:false};
 const profile=await f.api('PUT','/settings',settings);assert.equal(profile.status,200);
 const saved=await f.api('PUT',path,{...checks,settingsVersion:1});assert.equal(saved.status,200);assert.equal(saved.body.ready,true);assert.equal(saved.body.officialReportGenerated,false);
 assert.equal((await f.api('GET','/tax-calendar/preparation/2026-02')).body.ready,false);
 assert.equal((await f.api('PUT',path,{...checks,settingsVersion:1})).status,409);
 assert.equal((await f.api('PUT','/settings',{...settings,version:1,legalName:'UPDATED TAX PROFILE'})).status,200);
 const changed=(await f.api('GET',path)).body;assert.equal(changed.profileCurrent,false);assert.equal(changed.ready,false);
 assert.equal((await f.api('PUT',path,{...checks,version:1,settingsVersion:1})).status,409);
 const confirmed=await f.api('PUT',path,{...checks,version:1,settingsVersion:2});assert.equal(confirmed.status,200);assert.equal(confirmed.body.ready,true);assert.equal(confirmed.body.version,2);
 assert.equal((await f.api('GET','/tax-calendar/preparation/2026-13')).status,400);
});

test('calendar counts cover all filtered tasks while pagination and cancellation preserve records',async t=>{
 const f=await fixture(t),create=async(title,dueDate,status='OPEN')=>{const r=await f.api('POST','/tax-calendar',{title,dueDate,status,category:'OTHER',dueDateConfirmed:true});assert.equal(r.status,200);return r.body;};
 const old=await create('Overdue task','2000-01-01');await create('Done task','2000-01-02','DONE');await create('Future task','2099-01-01');
 let r=(await f.api('GET','/tax-calendar?limit=1&from=2000-01-01&to=2000-01-31')).body;
 assert.equal(r.items.length,1);assert.equal(r.counts.total,2);assert.equal(r.counts.overdue,1);assert.ok(r.nextCursor);
 const next=(await f.api('GET',`/tax-calendar?limit=1&from=2000-01-01&to=2000-01-31&after=${r.nextCursor}`)).body;assert.equal(next.items.length,1);assert.notEqual(next.items[0].id,r.items[0].id);assert.deepEqual(next.counts,r.counts);
 const cancel=await f.api('PUT','/tax-calendar/'+old.id,{title:old.title,dueDate:old.due_date,status:'CANCELLED',category:'OTHER',dueDateConfirmed:true,version:1});assert.equal(cancel.status,200);
 r=(await f.api('GET','/tax-calendar?status=OPEN')).body;assert.equal(r.counts.total,1);assert.equal(r.counts.overdue,0);
});

test('production ignores registration flags and explicit test registration overrides',async t=>{
 const directory=await mkdtemp(join(tmpdir(),'muchet-private-production-')),schema=testSchema();
 let app;const previousEnv=process.env.APP_ENV,previousFlag=process.env.ALLOW_REGISTRATION;
 try{
  process.env.APP_ENV='production';process.env.ALLOW_REGISTRATION='true';
  app=await createApp({dataDir:directory,schema,allowRegistration:true});
 }finally{
  if(previousEnv===undefined)delete process.env.APP_ENV;else process.env.APP_ENV=previousEnv;
  if(previousFlag===undefined)delete process.env.ALLOW_REGISTRATION;else process.env.ALLOW_REGISTRATION=previousFlag;
 }
 t.after(async()=>{if(app){await app.db.exec(`DROP SCHEMA "${schema}" CASCADE`);await app.close();}await rm(directory,{recursive:true,force:true});});
 const response=await app.inject({method:'POST',url:'/v1/auth/register',payload:{login:'uninvited@example.test',password:'SYNTHETIC PASSWORD',name:'Uninvited'}});
 assert.equal(response.statusCode,403);assert.equal(response.json().error,'registration_disabled');
 assert.equal((await app.db.prepare('SELECT count(*) AS n FROM users').get()).n,0);
});

test('global company search respects category permissions and company boundaries and treats wildcard characters literally',async t=>{
 const f=await fixture(t),name='NEEDLE SEARCH';
 const project=(await f.api('POST','/projects',{name})).body;
 const service=(await f.api('POST','/resources/services',{data:{name:name+' SERVICE'}})).body;
 const employee=(await f.api('POST','/employees',{name:name+' PRIVATE EMPLOYEE',identifier:'111111111111',jobTitle:'SYNTHETIC JOB',hireDate:'2026-01-01',grossBase:0,status:'ACTIVE',resident:true,citizenship:'KZ',standardDeductionDeclaration:false})).body;assert.ok(employee.id);
 const result=await f.api('GET','/search?q=NEEDLE');assert.equal(result.status,200,JSON.stringify(result.body));
 assert.ok(result.body.items.some(x=>x.id===project.id&&x.kind==='PROJECT'));assert.ok(result.body.items.some(x=>x.id===employee.id&&x.kind==='EMPLOYEE'));assert.equal(JSON.stringify(result.body).includes('111111111111'),false);
 const reader=await f.user('search-reader@example.test');assert.equal((await f.call('GET',f.prefix+'/search?q=NEEDLE',null,reader.token)).status,404);
 await f.api('PUT',`/members/${reader.id}`,{permissions:['catalog.read']});
 const limited=(await f.call('GET',f.prefix+'/search?q=NEEDLE',null,reader.token)).body.items;assert.deepEqual(limited.map(x=>x.id),[service.id]);
 assert.equal((await f.call('GET',f.prefix+'/search?q=111111111111',null,reader.token)).body.items.length,0);
 await f.api('PUT',`/members/${reader.id}`,{permissions:[]});assert.deepEqual((await f.call('GET',f.prefix+'/search?q=NEEDLE',null,reader.token)).body.items,[]);
 const foreign=(await f.call('POST','/v1/companies',{name:'Other firm',currency:'KZT'},reader.token)).body;
 await f.call('POST',`/v1/companies/${foreign.id}/resources/services`,{data:{name:'NEEDLE FOREIGN'}},reader.token,randomUUID());
 assert.equal((await f.api('GET','/search?q=FOREIGN')).body.items.length,0);
 const literal=(await f.api('POST','/resources/services',{data:{name:'Literal100%_ entry'}})).body;
 await f.api('POST','/resources/services',{data:{name:'Literal100xx entry'}});
 assert.deepEqual((await f.api('GET','/search?q='+encodeURIComponent('100%_'))).body.items.map(x=>x.id),[literal.id]);
 assert.equal((await f.api('GET','/search?q=N')).status,400);assert.equal((await f.api('GET','/search?q=NEEDLE&limit=51')).status,400);
});

test('global search finds numbered service and goods documents and reports a bounded result set',async t=>{
 const f=await commercialFixture(t),refs=await f.catalog();
 const act=(await f.api('POST','/commercial-documents',f.body)).body;
 const goods=(await f.api('POST','/orders',{businessDate:'2026-01-01',counterpartyId:f.client.id,items:[{...refs,quantity:1,unitPrice:100}]})).body;
 let result=(await f.api('GET','/search?q='+encodeURIComponent(act.number))).body;
 assert.ok(result.items.some(x=>x.id===act.id&&x.kind==='SALE_ACT'));
 result=(await f.api('GET','/search?q='+encodeURIComponent(goods.number))).body;assert.ok(result.items.some(x=>x.id===goods.id&&x.kind==='GOODS'));
 result=(await f.api('GET','/search?q=SYNTHETIC')).body;
 assert.ok(result.items.some(x=>x.id===act.id));assert.ok(result.items.some(x=>x.id===goods.id));
 result=(await f.api('GET','/search?q=SYNTHETIC&limit=1')).body;assert.equal(result.items.length,1);assert.equal(result.hasMore,true);
});

test('production request logs omit search queries, credentials and private database error details',async t=>{
 let logs='';const stream=new Writable({write(chunk,_encoding,done){logs+=chunk.toString();done();}});
 const f=await fixture(t,{logger:privateLoggerOptions({stream})});
 await f.api('GET','/search?q=private-iin-111111111111');
 const prepare=f.app.db.prepare;
 f.app.db.prepare=sql=>{if(sql.startsWith('SELECT id,name AS title'))throw Object.assign(new Error('SECRET_SQL_RECORD'),{code:'23514',detail:'SECRET_ROW_CONTENT'});return prepare(sql);};
 try{assert.equal((await f.api('GET','/search?q=force-error')).status,500);}finally{f.app.db.prepare=prepare;}
 assert.ok(logs.includes('23514'));assert.equal(logs.includes('SECRET_SQL_RECORD'),false);assert.equal(logs.includes('SECRET_ROW_CONTENT'),false);
 assert.equal(logs.includes('private-iin-111111111111'),false);
 assert.equal(logs.includes('correct-horse-battery'),false);assert.equal(logs.includes(f.owner.token),false);
});

async function debtFixture(t,type='AR'){
 const f=await fixture(t),kind=type==='AR'?'clients':'suppliers';
 const party=(await f.api('POST','/resources/'+kind,{data:{name:'SYNTHETIC OPENING PARTY'}})).body;
 const project=(await f.api('POST','/projects',{name:'SYNTHETIC OPENING A'})).body;
 const wallet=(await f.api('POST','/wallets',{name:'SYNTHETIC OPENING CASH'})).body;
 const otherWallet=(await f.api('POST','/wallets',{name:'SYNTHETIC OPENING BANK'})).body;
 const body={type,counterpartyId:party.id,amount:500,projectId:project.id,businessDate:'2026-01-10',dueDate:'2026-01-31'};
 const created=await f.api('POST','/debts',body);assert.equal(created.status,200,JSON.stringify(created.body));
 return {...f,party,project,wallet,otherWallet,body,debt:created.body};
}
test('paid opening debt corrections preserve cash and move advances and dated balances across projects after close',async t=>{
 const f=await debtFixture(t),other=(await f.api('POST','/projects',{name:'SYNTHETIC OPENING B'})).body;
 const key=randomUUID(),payment={walletId:f.wallet.id,amount:300,businessDate:'2026-01-05',debtVersion:f.debt.version};
 const paid=await f.api('POST',`/debts/${f.debt.id}/settlements`,payment,key);assert.equal(paid.status,200);assert.deepEqual((await f.api('POST',`/debts/${f.debt.id}/settlements`,payment,key)).body,paid.body);
 let current=(await f.api('GET','/debts/'+f.debt.id)).body;assert.equal(current.remaining,200);assert.equal(current.version,2);
 await f.api('POST','/periods/2026-01/close',{reason:'SYNTHETIC REVIEWED'});
 const edit=await f.api('PUT','/debts/'+f.debt.id,{...f.body,version:current.version,amount:200,projectId:other.id,businessDate:'2026-02-10'});assert.equal(edit.status,200,JSON.stringify(edit.body));current=edit.body;
 assert.equal(current.remaining,0);assert.equal(current.advance,100);assert.equal(current.paid,300);assert.equal(current.sourceComplete,true);
 assert.equal((await f.api('GET','/wallets')).body.items.find(w=>w.id===f.wallet.id).balance,300);
 const january=(await f.api('GET',`/accounting/trial-balance?to=2026-01-31&projectId=${other.id}`)).body.accounts;
 assert.equal(january.find(a=>a.account==='customer_advances').balance,-300);assert.equal(january.find(a=>a.account==='receivables')?.balance??0,0);
 const oldProject=(await f.api('GET',`/accounting/trial-balance?projectId=${f.project.id}`)).body.accounts;
 assert.ok(oldProject.every(a=>a.balance===0));
 assert.equal((await f.api('GET','/reports/profit-loss')).body.netProfit,0);
 assert.equal((await f.api('PUT','/debts/'+f.debt.id,{...f.body,version:1})).status,409);
 assert.equal((await f.api('GET',`/debts/${f.debt.id}/history`)).body.items.length,1);
});
test('opening debt payment edits, voided corrections and restore preserve source history and exclude cancelled bank candidates',async t=>{
 const f=await debtFixture(t);const paid=(await f.api('POST',`/debts/${f.debt.id}/settlements`,{walletId:f.wallet.id,amount:300,businessDate:'2026-01-05'})).body;
 const path=`/debts/${f.debt.id}/payments/${paid.id}`;
 const edit=await f.api('PUT',path,{version:1,walletId:f.otherWallet.id,amount:150,businessDate:'2026-01-07'});assert.equal(edit.status,200);const oldJournal=edit.body.journal_id;
 assert.equal((await f.api('POST',path+'/void',{version:2})).status,200);
 const inactiveEdit=await f.api('PUT',path,{version:3,walletId:f.wallet.id,amount:600,businessDate:'2026-01-06'});assert.equal(inactiveEdit.status,200);
 assert.equal((await f.api('GET','/wallets')).body.items.find(w=>w.id===f.wallet.id).balance,0,'editing a voided payment must not change money');
 const restored=await f.api('POST',path+'/restore',{version:4,allowAdvance:true});assert.equal(restored.status,200,JSON.stringify(restored.body));assert.notEqual(restored.body.journal_id,oldJournal);
 const debt=(await f.api('GET','/debts/'+f.debt.id)).body;assert.equal(debt.advance,100);assert.equal(debt.remaining,0);
 const wallets=(await f.api('GET','/wallets')).body.items;assert.equal(wallets.find(w=>w.id===f.wallet.id).balance,600);assert.equal(wallets.find(w=>w.id===f.otherWallet.id).balance,0);
 const source=(await f.api('GET','/accounting/journal/'+restored.body.journal_id)).body;assert.equal(source.sourceDebtId,f.debt.id);
 assert.equal((await f.api('PUT','/accounting/journal/'+source.id,{lines:[{account:`wallet:${f.wallet.id}`,debit:1},{account:'capital',credit:1}]})).status,409);
 assert.equal((await f.api('PUT','/accounting/journal/'+source.id,{description:'Manual: renamed source'})).status,200);
 assert.equal((await f.api('POST','/accounting/journal/'+source.id+'/reverse',{reason:'Attempted bypass'})).status,409);
 const statement=await f.api('POST','/bank-imports',{walletId:f.otherWallet.id,filename:'SYNTHETIC old debt.csv',csv:'date;reference;debit;credit;description\n2026-01-07;old-debt;0;1.50;SYNTHETIC old entry'});assert.equal(statement.status,200);
 const imported=(await f.api('GET',`/bank-imports/${statement.body.id}`)).body;
 const candidate=(await f.api('GET',`/bank-imports/${statement.body.id}/rows/${imported.items[0].id}/candidates`)).body;assert.equal(candidate.items.length,0);
 assert.equal((await f.api('GET',`/debts/${f.debt.id}/history`)).body.items.length,4);
 const activeImport=(await f.api('POST','/bank-imports',{walletId:f.wallet.id,csv:'date;reference;debit;credit;description\n2026-01-06;active-debt;0;6.00;SYNTHETIC active entry'})).body;
 const activeRow=(await f.api('GET',`/bank-imports/${activeImport.id}`)).body.items[0],activePath=`/bank-imports/${activeImport.id}/rows/${activeRow.id}`;
 const activeCandidates=(await f.api('GET',activePath+'/candidates')).body.items;assert.equal(activeCandidates.length,1);
 assert.equal((await f.api('PUT',activePath,{version:1,classification:'EXISTING',entryId:activeCandidates[0].id})).status,200);
 assert.equal((await f.api('POST',activePath+'/post',{version:2})).status,200);
 let linked=(await f.api('GET',`/bank-imports/${activeImport.id}`)).body.items[0];assert.equal(linked.source_debt_id,f.debt.id);assert.equal(linked.payment_voided,false);
 assert.equal((await f.api('POST',path+'/void',{version:5})).status,200);
 linked=(await f.api('GET',`/bank-imports/${activeImport.id}`)).body.items[0];assert.equal(linked.payment_voided,true);
});
test('supplier debt refunds and changing opening debt direction never rewrite the actual direction of cash',async t=>{
 const f=await debtFixture(t,'AP');await f.api('POST',`/wallets/${f.wallet.id}/transactions`,{type:'CAPITAL',amount:2000,description:'SYNTHETIC FUNDS'});
 assert.equal((await f.api('POST',`/debts/${f.debt.id}/settlements`,{walletId:f.wallet.id,amount:300,businessDate:'2026-01-05'})).status,200);
 assert.equal((await f.api('POST',`/debts/${f.debt.id}/settlements`,{walletId:f.wallet.id,amount:100,direction:'IN',businessDate:'2026-01-15'})).status,200);
 let current=(await f.api('GET','/debts/'+f.debt.id)).body;assert.equal(current.remaining,300);assert.equal(current.paid,200);assert.equal(current.paidOut,300);assert.equal(current.received,100);
 const client=(await f.api('POST','/resources/clients',{data:{name:'SYNTHETIC CORRECTED CLIENT'}})).body;
 const corrected=await f.api('PUT','/debts/'+f.debt.id,{...f.body,version:current.version,type:'AR',counterpartyId:client.id,amount:400});assert.equal(corrected.status,200,JSON.stringify(corrected.body));assert.equal(corrected.body.remaining,600);
 current=(await f.api('POST',`/debts/${f.debt.id}/cancel`,{version:corrected.body.version})).body;assert.equal(current.status,'CANCELLED');assert.equal(current.remaining,200,'the actual cash paid out still forms a receivable');
 current=(await f.api('POST',`/debts/${f.debt.id}/restore`,{version:current.version})).body;assert.equal(current.remaining,600);
 assert.equal((await f.api('GET','/wallets')).body.items.find(w=>w.id===f.wallet.id).balance,1800);
 assert.equal((await f.api('GET','/reports/profit-loss')).body.netProfit,0);
});
test('spent debt receipts cannot be removed or moved without funds while non-cash historical corrections remain available',async t=>{
 const f=await debtFixture(t),paid=(await f.api('POST',`/debts/${f.debt.id}/settlements`,{walletId:f.wallet.id,amount:300})).body;
 await f.api('POST',`/wallets/${f.wallet.id}/transactions`,{type:'EXPENSE',amount:250,description:'SYNTHETIC SPENT CASH'});
 const path=`/debts/${f.debt.id}/payments/${paid.id}`;
 assert.equal((await f.api('POST',path+'/void',{version:1})).status,409);
 assert.equal((await f.api('PUT',path,{version:1,walletId:f.otherWallet.id,amount:300})).status,409);
 assert.equal((await f.api('GET',`/debts/${f.debt.id}/payments`)).body.items[0].version,1);
 const current=(await f.api('GET','/debts/'+f.debt.id)).body;
 const correction=await f.api('PUT','/debts/'+f.debt.id,{...f.body,version:current.version,amount:200});assert.equal(correction.status,200);assert.equal(correction.body.advance,100);
 const wallets=(await f.api('GET','/wallets')).body.items;assert.equal(wallets.find(w=>w.id===f.wallet.id).balance,50);assert.equal(wallets.find(w=>w.id===f.otherWallet.id).balance,0);
});
test('opening debt operations require cash authority, company-owned references and real Gregorian dates',async t=>{
 const f=await debtFixture(t),reader=await f.user('debt-reader@example.test');
 await f.api('PUT',`/members/${reader.id}`,{permissions:['debts.read','debts.settle']});
 const blocked=await f.call('POST',f.prefix+`/debts/${f.debt.id}/settlements`,{walletId:f.wallet.id,amount:100},reader.token,randomUUID());assert.equal(blocked.status,403);
 assert.equal((await f.api('GET',`/debts/${f.debt.id}/payments`)).body.items.length,0);
 assert.equal((await f.api('POST','/debts',{...f.body,businessDate:'0000-01-01'})).status,400);
 assert.equal((await f.api('POST','/debts',{...f.body,dueDate:'2026-02-30'})).status,400);
 const foreign=(await f.call('POST','/v1/companies',{name:'Foreign debt firm',currency:'KZT'},reader.token)).body;
 const party=(await f.call('POST',`/v1/companies/${foreign.id}/resources/clients`,{data:{name:'Foreign party'}},reader.token,randomUUID())).body;
 assert.equal((await f.api('POST','/debts',{...f.body,counterpartyId:party.id})).status,404);
 assert.equal((await f.call('GET',`/v1/companies/${foreign.id}/debts/${f.debt.id}`,null,reader.token)).status,404);
 const summary=(await f.api('GET','/debts?scope=ACCOUNTING&limit=1')).body;assert.equal(summary.summary[0].outstanding,500);
});

test('opening debt reads keep one financial snapshot while a concurrent payment is committed',async t=>{
 const f=await debtFixture(t),prepare=f.app.db.prepare;
 let announce,release;const readStarted=new Promise(resolve=>announce=resolve),resume=new Promise(resolve=>release=resolve);let paused=false;
 f.app.db.prepare=sql=>{const statement=prepare(sql);if(sql==='SELECT * FROM debts WHERE company_id=? AND id=?')return {...statement,get:async(...args)=>{const result=await statement.get(...args);if(!paused){paused=true;announce();await resume;}return result;}};return statement;};
 let reading;
 try{
  reading=f.api('GET','/debts/'+f.debt.id);await readStarted;
  const paid=await f.api('POST',`/debts/${f.debt.id}/settlements`,{walletId:f.wallet.id,amount:300});assert.equal(paid.status,200);
  release();const snapshot=await reading;assert.equal(snapshot.body.version,1);assert.equal(snapshot.body.paid,0);assert.equal(snapshot.body.remaining,500);
 }finally{release();f.app.db.prepare=prepare;if(reading)await reading;}
 const latest=(await f.api('GET','/debts/'+f.debt.id)).body;assert.equal(latest.version,2);assert.equal(latest.paid,300);assert.equal(latest.remaining,200);
});

test('a renamed cash transfer cannot bypass its business source through manual journal edit or reversal',async t=>{
 const f=await fixture(t),a=(await f.api('POST','/wallets',{name:'Transfer guard A'})).body,b=(await f.api('POST','/wallets',{name:'Transfer guard B'})).body;
 await f.api('POST',`/wallets/${a.id}/transactions`,{type:'CAPITAL',amount:1000,description:'SYNTHETIC SOURCE FUNDS'});
 const transfer=(await f.api('POST','/wallet-transfers',{sourceWalletId:a.id,targetWalletId:b.id,amount:200})).body;
 const rows=(await f.api('GET',`/wallets/${a.id}/entries`)).body.items;const journalId=rows.find(e=>e.reference_id===transfer.id).journal_id;
 assert.equal((await f.api('PUT','/accounting/journal/'+journalId,{description:'Manual: source renamed'})).status,200);
 assert.equal((await f.api('POST','/accounting/journal/'+journalId+'/reverse',{reason:'Attempted source bypass'})).status,409);
 assert.equal((await f.api('PUT','/accounting/journal/'+journalId,{lines:[{account:`wallet:${a.id}`,credit:100},{account:`wallet:${b.id}`,debit:100}]})).status,409);
 const wallets=(await f.api('GET','/wallets')).body.items;assert.equal(wallets.find(w=>w.id===a.id).balance,800);assert.equal(wallets.find(w=>w.id===b.id).balance,200);
});

 test('opening debts participate in company search only with debt read permission',async t=>{
 const f=await debtFixture(t);
 const result=(await f.api('GET','/search?q='+f.debt.id)).body;
 assert.ok(result.items.some(x=>x.kind==='DEBT'&&x.id===f.debt.id));
 const reader=await f.user('debt-search@example.test');
 await f.api('PUT',`/members/${reader.id}`,{permissions:['catalog.read']});
 const privateResult=await f.call('GET',f.prefix+'/search?q='+f.debt.id,null,reader.token);
 assert.equal(privateResult.status,200);assert.equal(privateResult.body.items.length,0);
 });

test('bank unmatch releases only an existing link with version, permissions and history while preserving real cash',async t=>{
 const f=await fixture(t),wallet=(await f.api('POST','/wallets',{name:'SYNTHETIC UNMATCH BANK'})).body;
 await f.api('POST',`/wallets/${wallet.id}/transactions`,{type:'INCOME',amount:1234,businessDate:'2026-01-05',description:'SYNTHETIC REAL PAYMENT'});
 const source=(await f.api('GET',`/wallets/${wallet.id}/entries`)).body.items[0];
 const imported=(await f.api('POST','/bank-imports',{walletId:wallet.id,csv:'date;reference;debit;credit;description\n2026-01-05;unmatch-a;0;12.34;SYNTHETIC A\n2026-01-05;unmatch-b;0;12.34;SYNTHETIC B'})).body;
 const rows=(await f.api('GET',`/bank-imports/${imported.id}`)).body.items;
 const path=id=>`/bank-imports/${imported.id}/rows/${id}`;
 await f.api('PUT',path(rows[0].id),{version:1,classification:'EXISTING',entryId:source.id});
 await f.api('POST',path(rows[0].id)+'/post',{version:2});
 const before=(await f.api('GET','/accounting/journal')).body.items.length;
 const reader=await f.user('bank-unmatch-reader@example.test');await f.api('PUT',`/members/${reader.id}`,{permissions:['bank.review']});
 assert.equal((await f.call('POST',f.prefix+path(rows[0].id)+'/unmatch',{version:3,reason:'Attempt without bank.post'},reader.token,randomUUID())).status,403);
 assert.equal((await f.api('POST',path(rows[0].id)+'/unmatch',{version:2,reason:'Stale'})).status,409);
 assert.equal((await f.api('POST',path(rows[0].id)+'/unmatch',{version:3,reason:''})).status,400);
 const key=randomUUID(),payload={version:3,reason:'SYNTHETIC WRONG LINK'};
 const cleared=await f.api('POST',path(rows[0].id)+'/unmatch',payload,key);assert.equal(cleared.status,200);assert.equal(cleared.body.version,4);assert.equal(cleared.body.journal_id,null);assert.equal(cleared.body.classification,null);assert.equal(cleared.body.matched_entry_id,null);
 assert.deepEqual((await f.api('POST',path(rows[0].id)+'/unmatch',payload,key)).body,cleared.body);
 assert.equal((await f.api('GET','/accounting/journal')).body.items.length,before);assert.equal((await f.api('GET','/wallets')).body.items[0].balance,1234);
 assert.equal((await f.api('GET',path(rows[1].id)+'/candidates')).body.items[0].id,source.id);
 const history=await f.app.db.prepare("SELECT snapshot FROM entity_history WHERE company_id=? AND kind='bank_row' AND entity_id=? ORDER BY revision DESC LIMIT 1").get(f.company.id,rows[0].id);assert.equal(history.snapshot.unmatchReason,payload.reason);assert.equal(history.snapshot.journal_id,source.journal_id);
 await f.api('PUT',path(rows[1].id),{version:1,classification:'EXISTING',entryId:source.id});await f.api('POST',path(rows[1].id)+'/post',{version:2});
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,1234);
 assert.equal((await f.api('POST',path(rows[0].id)+'/unmatch',{version:4,reason:'Already released'})).status,409);
 await f.api('PUT',`/wallets/${wallet.id}/entries/${source.id}`,{type:'INCOME',amount:1200,businessDate:'2026-01-05',description:'SYNTHETIC CORRECTED PAYMENT'});
 assert.equal((await f.api('GET',`/bank-imports/${imported.id}`)).body.items.find(r=>r.id===rows[1].id).reconciliation_status,'SOURCE_CHANGED');
 assert.equal((await f.api('POST',path(rows[1].id)+'/unmatch',{version:3,reason:'Source corrected after reconciliation'})).status,200);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,1200);
 const ownImport=(await f.api('POST','/bank-imports',{walletId:wallet.id,csv:'date;reference;debit;credit;description\n2026-01-06;created-bank-income;0;1.00;SYNTHETIC NEW PAYMENT'})).body;
 const ownRow=(await f.api('GET',`/bank-imports/${ownImport.id}`)).body.items[0],ownPath=`/bank-imports/${ownImport.id}/rows/${ownRow.id}`;
 await f.api('PUT',ownPath,{version:1,classification:'INCOME'});await f.api('POST',ownPath+'/post',{version:2});
 assert.equal((await f.api('POST',ownPath+'/unmatch',{version:3,reason:'Cannot disguise removal of new money'})).status,409);
 assert.equal((await f.api('GET','/wallets')).body.items[0].balance,1300);

});
