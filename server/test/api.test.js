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
  assert.equal((await app.db.prepare('SELECT count(*) AS n FROM schema_versions').get()).n, 6);
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
