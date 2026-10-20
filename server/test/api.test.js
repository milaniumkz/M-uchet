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
  assert.equal((await app.db.prepare('SELECT count(*) AS n FROM schema_versions').get()).n, 12);
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
