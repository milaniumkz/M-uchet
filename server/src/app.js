import Fastify from 'fastify';
import cors from '@fastify/cors';
import staticFiles from '@fastify/static';
import rateLimit from '@fastify/rate-limit';
import multipart from '@fastify/multipart';
import swagger from '@fastify/swagger';
import { randomUUID } from 'node:crypto';
import { mkdirSync, createReadStream } from 'node:fs';
import { writeFile, unlink } from 'node:fs/promises';
import { resolve } from 'node:path';
import { openDatabase, transaction } from './db.js';
import { hashPassword, verifyPassword, newToken, hashToken, fail, text, integer, scope, businessDate } from './security.js';
import { postJournal, allocate, orderInput, projectReference, registerManualWalletEntries } from './accounting.js';
import { kinds, permissions } from './resources.js';
import { registerCommercialRoutes } from './commercial.js';
import { registerEmployeeRoutes } from './employees.js';
import { registerAssetRoutes } from './assets.js';
import { resetPassword } from './recovery.js';
import { registerBankRoutes } from './banking.js';
import { registerBusinessRoutes } from './business.js';

const now = () => new Date().toISOString();
const object = value => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail(400, 'object_required');
  return value;
};
const publicUser = user => ({ id: user.id, login: user.login, name: user.name });

export async function createApp(options = {}) {
  const dataDir = resolve(options.dataDir ?? process.env.DATA_DIR ?? './var');
  const db = await openDatabase({ connectionString: options.databaseUrl, schema: options.schema });
  const fileDir = resolve(dataDir, 'uploads');
  mkdirSync(fileDir, { recursive: true, mode: 0o700 });
  const app = Fastify({ logger: options.logger ?? false, bodyLimit: 256 * 1024, trustProxy: false });
  app.decorate('db', db);
  app.addHook('onClose', async () => db.close());
  await app.register(cors, { origin: options.corsOrigin ?? process.env.CORS_ORIGIN ?? false, credentials: false });
  await app.register(rateLimit, { max: 300, timeWindow: '1 minute' });
  await app.register(multipart, { limits: { fileSize: 10 * 1024 * 1024, files: 1, fields: 0 } });
  await app.register(swagger, { openapi: { info: { title: 'M-uchet private API', version: '0.2.0' },
    components: { securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer' } } } },
    transform({schema,url,route}) {
      const documented={...schema};
      if(url.startsWith('/v1/')&&!['/v1/auth/login','/v1/auth/register','/v1/auth/reset-password'].includes(url))documented.security=[{bearerAuth:[]}];
      if(['POST','PUT'].includes(route.method)&&!url.endsWith('/files'))documented.body={type:'object',additionalProperties:true,description:'See docs/API.md and server/README.md for required fields; typed request schemas are pending.'};
      return {schema:documented,url};
    } });
  const registration = options.allowRegistration ?? process.env.ALLOW_REGISTRATION === 'true';
  const dummyPassword = await hashPassword(newToken());

  app.setErrorHandler((error, request, reply) => {
    const status = error.statusCode >= 400 && error.statusCode < 500 ? error.statusCode : 500;
    if (status === 500) request.log.error({ err: error }, 'request failed');
    reply.code(status).send({ error: status === 500 ? 'internal_error' : (error.code ?? 'invalid_request'), requestId: request.id });
  });
  app.addHook('onSend', async (request, reply) => {
    reply.header('X-Content-Type-Options', 'nosniff');
    reply.header('Cache-Control', 'no-store');
    const web = options.webRoot && !request.url.startsWith('/v1/') && !['/health','/openapi.json'].includes(request.url.split('?')[0]);
    reply.header('Content-Security-Policy', web
      ? "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; connect-src 'self'; font-src 'self'; img-src 'self' data: blob:; worker-src 'self' blob:; base-uri 'self'; object-src 'none'; frame-ancestors 'none'"
      : "default-src 'none'; frame-ancestors 'none'");
  });
  const auth = async request => {
    const match = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(request.headers.authorization ?? '');
    if (!match) fail(401, 'authentication_required');
    const user = (await db.prepare(`SELECT u.* FROM sessions s JOIN users u ON u.id=s.user_id
      WHERE s.token_hash=? AND s.expires_at>?`).get(hashToken(match[1]), Date.now()));
    if (!user) fail(401, 'invalid_session');
    request.user = publicUser(user);
    request.tokenHash = hashToken(match[1]);
  };
  const access = async (request, permission) => {
    const companyId = request.params.companyId;
    const membership = (await db.prepare('SELECT * FROM memberships WHERE company_id=? AND user_id=?').get(companyId, request.user.id));
    if (!membership) fail(404, 'company_not_found');
    if (membership.role !== 'owner' && !JSON.parse(membership.permissions).includes(permission)) fail(403, 'permission_denied');
    return (await db.prepare('SELECT * FROM companies WHERE id=?').get(companyId));
  };
  const owner = async request => {
    const company = (await access(request, '__owner_only__'));
    return company;
  };
  const audit = async (request, action, id) => (await db.prepare(`INSERT INTO audit(company_id,actor_id,action,resource_id,created_at)
    VALUES(?,?,?,?,?)`).run(request.params.companyId, request.user.id, action, id, now()));
  const command = async (request, permission, action, fn) => {
    const key = text(request.headers['idempotency-key'], 'idempotency_key', 128);
    const fingerprint = hashToken(JSON.stringify([request.method, request.url, request.body ?? null]));
    return (await transaction(db, async () => {
      // Serialize business commands per organization on a persistent row lock.
      // This covers stock, balances and idempotency across concurrent processes.
      await db.prepare('SELECT id FROM companies WHERE id=? FOR UPDATE').get(request.params.companyId);
      const company = await access(request, permission);
      await db.prepare("SELECT set_config('app.actor_id',?,true)").get(request.user.id);
      company.businessDate = businessDate(request.body?.businessDate, company.timezone);
      const old = (await db.prepare('SELECT * FROM idempotency WHERE company_id=? AND actor_id=? AND key=?').get(company.id, request.user.id, key));
      if (old) {
        if (old.fingerprint !== fingerprint) fail(409, 'idempotency_conflict');
        return JSON.parse(old.response);
      }
      const result = await fn(company);
      (await audit(request, action, result.id ?? company.id));
      (await db.prepare('INSERT INTO idempotency VALUES(?,?,?,?,?)').run(company.id, request.user.id, key, fingerprint, JSON.stringify(result)));
      return result;
    }));
  };
  const pageLimit = query => {
    const n = Number(query.limit ?? 50);
    if (!Number.isInteger(n) || n < 1 || n > 200) fail(400, 'invalid_limit');
    return n;
  };
  app.get('/health', async () => { const row = (await db.prepare('SELECT MAX(version) AS version FROM schema_versions').get()); return { status: 'ok', schemaVersion: row.version }; });
  app.get('/openapi.json', async () => app.swagger());
  app.get('/v1/capabilities', { preHandler: auth }, async () => ({ permissions, resources: kinds, costingMethods: ['FIFO'], quantityFormat: 'positive integer base units', moneyFormat: 'integer minor currency units' }));

  app.post('/v1/auth/register', { config: { rateLimit: { max: 5, timeWindow: '1 minute' } } }, async (request, reply) => {
    if (!registration) fail(403, 'registration_disabled');
    const body = object(request.body);
    const login = text(body.login, 'login', 254).toLowerCase();
    const name = text(body.name, 'name');
    if (typeof body.password !== 'string' || body.password.length < 12 || body.password.length > 256) fail(400, 'password_length_12_to_256');
    const password = await hashPassword(body.password);
    const id = randomUUID();
    try { (await db.prepare('INSERT INTO users VALUES(?,?,?,?,?)').run(id, login, password, name, now())); }
    catch (error) { if ((await db.prepare('SELECT 1 FROM users WHERE login=?').get(login))) fail(409, 'login_unavailable'); throw error; }
    reply.code(201);
    return { id, login, name };
  });
  app.post('/v1/auth/reset-password',{config:{rateLimit:{max:5,timeWindow:'1 minute'}}},request=>resetPassword(db,object(request.body)));
  app.post('/v1/auth/login', { config: { rateLimit: { max: 10, timeWindow: '1 minute' } } }, async request => {
    const body = object(request.body);
    const login = text(body.login, 'login', 254).toLowerCase();
    if (typeof body.password !== 'string' || body.password.length > 256) fail(400, 'invalid_password');
    const user = (await db.prepare('SELECT * FROM users WHERE login=?').get(login));
    const valid = await verifyPassword(body.password, user?.password ?? dummyPassword);
    if (!user || !valid) fail(401, 'invalid_credentials');
    const token = newToken(), expiresAt = Date.now() + 12 * 60 * 60 * 1000;
    (await db.prepare('DELETE FROM sessions WHERE expires_at<=?').run(Date.now()));
    (await db.prepare('INSERT INTO sessions VALUES(?,?,?)').run(hashToken(token), user.id, expiresAt));
    return { token, expiresAt, user: publicUser(user) };
  });
  app.post('/v1/auth/logout', { preHandler: auth }, async request => {
    (await db.prepare('DELETE FROM sessions WHERE token_hash=?').run(request.tokenHash));
    return { ok: true };
  });
  app.get('/v1/auth/me', { preHandler: auth }, async request => ({ ...request.user,
    memberships: (await db.prepare('SELECT company_id AS companyId,role,permissions FROM memberships WHERE user_id=?').all(request.user.id)).map(m => ({ ...m, permissions: JSON.parse(m.permissions) })) }));
  app.post('/v1/auth/password', { preHandler: auth, config: { rateLimit: { max: 5, timeWindow: '1 minute' } } }, async request => {
    const body = object(request.body);
    if (typeof body.oldPassword !== 'string' || body.oldPassword.length > 256 || typeof body.password !== 'string' || body.password.length < 12 || body.password.length > 256) fail(400, 'invalid_password');
    const user = (await db.prepare('SELECT * FROM users WHERE id=?').get(request.user.id));
    if (!await verifyPassword(body.oldPassword, user.password)) fail(401, 'invalid_credentials');
    const password = await hashPassword(body.password);
    (await transaction(db, async () => {
      (await db.prepare('UPDATE users SET password=? WHERE id=?').run(password, user.id));
      (await db.prepare('DELETE FROM sessions WHERE user_id=?').run(user.id));
    }));
    return { ok: true, reauthenticationRequired: true };
  });
  app.get('/v1/companies', { preHandler: auth }, async request => (await db.prepare(`SELECT c.* FROM companies c
    JOIN memberships m ON m.company_id=c.id WHERE m.user_id=? ORDER BY c.id`).all(request.user.id)));
  app.post('/v1/companies', { preHandler: auth }, async (request, reply) => {
    const body = object(request.body), name = text(body.name, 'name');
    if (!/^[A-Z]{3}$/.test(body.currency ?? '')) fail(400, 'invalid_currency');
    const key = request.headers['idempotency-key'] === undefined ? null : text(request.headers['idempotency-key'], 'idempotency_key', 128);
    const fingerprint = hashToken(JSON.stringify([request.method, request.url, body]));
    const result = await transaction(db, async () => {
      // Lock the existing actor row even when this is their first company.
      await db.prepare('SELECT id FROM users WHERE id=? FOR UPDATE').get(request.user.id);
      if (key) {
        const previous = await db.prepare('SELECT * FROM user_commands WHERE actor_id=? AND key=?').get(request.user.id, key);
        if (previous) {
          if (previous.fingerprint !== fingerprint) fail(409, 'idempotency_conflict');
          return JSON.parse(previous.response);
        }
      }
      const id = randomUUID();
      await db.prepare('INSERT INTO companies(id,name,currency,created_at) VALUES(?,?,?,?)').run(id, name, body.currency, now());
      await db.prepare("INSERT INTO memberships VALUES(?,?,'owner','[]')").run(id, request.user.id);
      const result = { id, name, currency: body.currency };
      await db.prepare('INSERT INTO audit(company_id,actor_id,action,resource_id,created_at) VALUES(?,?,?,?,?)')
        .run(id, request.user.id, 'company.create', id, now());
      if (key) await db.prepare('INSERT INTO user_commands VALUES(?,?,?,?,?)').run(request.user.id, key, fingerprint, JSON.stringify(result), now());
      return result;
    });
    reply.code(201); return result;
  });
  app.get('/v1/companies/:companyId/members', { preHandler: auth }, async request => {
    (await owner(request));
    return (await db.prepare(`SELECT m.user_id AS userId,u.name,m.role,m.permissions FROM memberships m JOIN users u ON u.id=m.user_id WHERE m.company_id=?`).all(request.params.companyId)).map(m => ({ ...m, permissions: JSON.parse(m.permissions) }));
  });
  app.put('/v1/companies/:companyId/members/:userId', { preHandler: auth }, async request => {
    (await owner(request));
    const body = object(request.body);
    if (!Array.isArray(body.permissions) || body.permissions.some(p => !permissions.includes(p))) fail(400, 'invalid_permissions');
    if (!(await db.prepare('SELECT 1 FROM users WHERE id=?').get(request.params.userId))) fail(404, 'user_not_found');
    return (await transaction(db, async () => {
      const old = (await db.prepare('SELECT role FROM memberships WHERE company_id=? AND user_id=?').get(request.params.companyId, request.params.userId));
      if (old?.role === 'owner') fail(409, 'owner_membership_protected');
      (await db.prepare(`INSERT INTO memberships VALUES(?,?,'member',?) ON CONFLICT(company_id,user_id) DO UPDATE SET permissions=excluded.permissions`).run(request.params.companyId, request.params.userId, JSON.stringify([...new Set(body.permissions)])));
      (await audit(request, 'membership.update', request.params.userId));
      return { ok: true };
    }));
  });
  app.delete('/v1/companies/:companyId/members/:userId', { preHandler: auth }, async request => {
    (await owner(request));
    return (await transaction(db, async () => {
      const old = (await db.prepare('SELECT role FROM memberships WHERE company_id=? AND user_id=?').get(request.params.companyId, request.params.userId));
      if (old?.role === 'owner') fail(409, 'owner_membership_protected');
      (await db.prepare('DELETE FROM memberships WHERE company_id=? AND user_id=?').run(request.params.companyId, request.params.userId));
      (await audit(request, 'membership.remove', request.params.userId));
      return { ok: true };
    }));
  });

  const resourceAccess = async (request, operation) => {
    const group = kinds[request.params.kind];
    if (!Object.hasOwn(kinds, request.params.kind)) fail(404, 'resource_not_found');
    return (await access(request, `${group}.${operation}`));
  };
  const document = row => ({ id: row.id, data: JSON.parse(row.data), version: row.version, createdAt: row.created_at, updatedAt: row.updated_at });
  const documentData = body => {
    const data = object(body.data);
    for (const key of ['companyId','company_id','idCompany','tenantId','role','permissions','ownerId','is_admin','password']) {
      if (Object.hasOwn(data, key)) fail(400, 'server_owned_field');
    }
    return JSON.stringify(data);
  };
  app.get('/v1/companies/:companyId/resources/:kind', { preHandler: auth }, async request => {
    (await resourceAccess(request, 'read'));
    const rows = (await db.prepare(`SELECT * FROM documents WHERE company_id=? AND kind=? AND id>? ORDER BY id LIMIT ?`).all(request.params.companyId, request.params.kind, request.query.after ?? '', pageLimit(request.query)));
    return { items: rows.map(document), nextCursor: rows.at(-1)?.id ?? null };
  });
  app.get('/v1/companies/:companyId/resources/:kind/:id', { preHandler: auth }, async request => {
    (await resourceAccess(request, 'read'));
    const row = (await db.prepare('SELECT * FROM documents WHERE company_id=? AND kind=? AND id=?').get(request.params.companyId, request.params.kind, request.params.id));
    if (!row) fail(404, 'document_not_found'); return document(row);
  });
  app.post('/v1/companies/:companyId/resources/:kind', { preHandler: auth }, async request => {
    (await resourceAccess(request, 'write'));
    const data = documentData(object(request.body)), id = randomUUID(), timestamp = now();
    const write=async()=>{
      await db.prepare('INSERT INTO documents VALUES(?,?,?,?,1,?,?)').run(request.params.companyId,request.params.kind,id,data,timestamp,timestamp);
      return {id,data:JSON.parse(data),version:1,createdAt:timestamp,updatedAt:timestamp};
    };
    if(request.headers['idempotency-key'])return command(request,`${kinds[request.params.kind]}.write`,`resource.${request.params.kind}.create`,write);
    return transaction(db,async()=>{const result=await write();await audit(request,`resource.${request.params.kind}.create`,id);return result;});
  });
  app.put('/v1/companies/:companyId/resources/:kind/:id', { preHandler: auth }, async request => {
    (await resourceAccess(request, 'write'));
    const body = object(request.body), data = documentData(body), version = integer(body.version, 'version', 1);
    const write=async()=>{
      const old=await db.prepare('SELECT * FROM documents WHERE company_id=? AND kind=? AND id=? AND version=? FOR UPDATE').get(request.params.companyId,request.params.kind,request.params.id,version);
      if(!old)fail(409,'version_conflict');
      await db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(request.params.companyId,request.params.kind,old.id,JSON.stringify(old),request.user.id);
      await db.prepare('UPDATE documents SET data=?,version=version+1,updated_at=? WHERE company_id=? AND kind=? AND id=?').run(data,now(),request.params.companyId,request.params.kind,request.params.id);
      return {id:old.id,data:JSON.parse(data),version:version+1};
    };
    if(request.headers['idempotency-key'])return command(request,`${kinds[request.params.kind]}.write`,`resource.${request.params.kind}.update`,write);
    return transaction(db,async()=>{const result=await write();await audit(request,`resource.${request.params.kind}.update`,request.params.id);return result;});
  });

  app.post('/v1/companies/:companyId/inventory/receipts', { preHandler: auth }, async request => (await command(request, 'inventory.receive', 'inventory.receive', async company => {
    const body = object(request.body);
    const parsed = (await orderInput(db, company.id, { scope: body.scope, projectId:body.projectId, items: [{ ...body, unitPrice: 0 }] }));
    const item = parsed.items[0], unitCost = integer(body.unitCost, 'unitCost');
    integer(item.quantity * unitCost, 'inventory_value');
    const id = randomUUID();
    (await db.prepare('INSERT INTO batches(id,company_id,product_id,warehouse_id,scope,quantity,reserved,unit_cost,created_at) VALUES(?,?,?,?,?,?,0,?,?)').run(id, company.id, item.productId, item.warehouseId, parsed.scope, item.quantity, unitCost, now()));
    const amount = item.quantity * unitCost;
    if (amount) (await postJournal(db, company, { scope: parsed.scope, projectId:parsed.projectId, description: `Receipt ${id}`, lines: [{ account: 'inventory', debit: amount }, { account: 'payables', credit: amount }] }));
    return { id, ...item, unitCost, scope: parsed.scope, projectId:parsed.projectId };
  })));
  app.get('/v1/companies/:companyId/inventory', { preHandler: auth }, async request => {
    (await access(request, 'inventory.read'));
    const items=await db.prepare('SELECT * FROM batches WHERE company_id=? AND id>? ORDER BY id LIMIT ?').all(request.params.companyId,request.query.after??'',pageLimit(request.query));
    return {items,nextCursor:items.length===pageLimit(request.query)?items.at(-1).id:null};
  });
  app.post('/v1/companies/:companyId/orders', { preHandler: auth }, async request => (await command(request, 'orders.write', 'order.create', async company => {
    const parsed = (await orderInput(db, company.id, object(request.body)));
    const id = randomUUID();
    (await db.prepare("INSERT INTO orders VALUES(?,?,'NEW',?,?)").run(id, company.id, JSON.stringify(parsed), now()));
    return { id, status: 'NEW', ...parsed };
  })));
  const getOrder = async (companyId, id) => {
    const row = (await db.prepare('SELECT * FROM orders WHERE company_id=? AND id=?').get(companyId, id));
    if (!row) fail(404, 'order_not_found');
    return { ...row, data: JSON.parse(row.data) };
  };
  app.get('/v1/companies/:companyId/orders', { preHandler: auth }, async request => {
    (await access(request, 'orders.read'));
    const selected=request.query.projectId;
    if(selected!==undefined && selected!=='unassigned')await projectReference(db,request.params.companyId,selected);
    const filter=selected===undefined?'':" AND data::jsonb->>'projectId' IS NOT DISTINCT FROM ?";
    return {items:(await db.prepare(`SELECT * FROM orders WHERE company_id=? AND id>?${filter} ORDER BY id LIMIT ?`).all(request.params.companyId,request.query.after??'',...(selected===undefined?[]:[selected==='unassigned'?null:selected]),pageLimit(request.query))).map(row=>({...row,data:JSON.parse(row.data)}))};
  });
  app.get('/v1/companies/:companyId/orders/:id', { preHandler: auth }, async request => { (await access(request, 'orders.read')); return (await getOrder(request.params.companyId, request.params.id)); });
  app.post('/v1/companies/:companyId/orders/:id/reserve', { preHandler: auth }, async request => (await command(request, 'orders.fulfill', 'order.reserve', async company => {
    const order = (await getOrder(company.id, request.params.id));
    if (order.status !== 'NEW') fail(409, 'invalid_order_state');
    for (const item of order.data.items) {
      for (const allocation of (await allocate(db, company.id, item, order.data.scope))) {
        (await db.prepare('UPDATE batches SET reserved=reserved+? WHERE id=?').run(allocation.quantity, allocation.batchId));
        (await db.prepare('INSERT INTO reservations VALUES(?,?,?)').run(order.id, allocation.batchId, allocation.quantity));
      }
    }
    (await db.prepare("UPDATE orders SET status='RESERVED' WHERE id=?").run(order.id));
    return { id: order.id, status: 'RESERVED' };
  })));
  app.post('/v1/companies/:companyId/orders/:id/cancel', { preHandler: auth }, async request => (await command(request, 'orders.write', 'order.cancel', async company => {
    const order = (await getOrder(company.id, request.params.id));
    if (!['NEW','RESERVED'].includes(order.status)) fail(409, 'invalid_order_state');
    for (const row of (await db.prepare('SELECT * FROM reservations WHERE order_id=?').all(order.id))) (await db.prepare('UPDATE batches SET reserved=reserved-? WHERE id=?').run(row.quantity, row.batch_id));
    (await db.prepare('DELETE FROM reservations WHERE order_id=?').run(order.id));
    (await db.prepare("UPDATE orders SET status='CANCELLED' WHERE id=?").run(order.id));
    return { id: order.id, status: 'CANCELLED' };
  })));
  app.post('/v1/companies/:companyId/orders/:id/ship', { preHandler: auth }, async request => (await command(request, 'orders.fulfill', 'order.ship', async company => {
    const order = (await getOrder(company.id, request.params.id));
    if (order.status !== 'RESERVED') fail(409, 'invalid_order_state');
    let cogs = 0;
    for (const row of (await db.prepare('SELECT r.*,b.unit_cost FROM reservations r JOIN batches b ON b.id=r.batch_id WHERE r.order_id=?').all(order.id))) {
      await db.prepare('INSERT INTO shipment_allocations VALUES(?,?,?,?)').run(order.id,row.batch_id,row.quantity,row.unit_cost);
      (await db.prepare('UPDATE batches SET quantity=quantity-?,reserved=reserved-? WHERE id=?').run(row.quantity, row.quantity, row.batch_id));
      cogs += row.quantity * row.unit_cost;
    }
    integer(cogs, 'cogs');
    (await db.prepare('DELETE FROM reservations WHERE order_id=?').run(order.id));
    (await db.prepare("UPDATE orders SET status='SHIPPED' WHERE id=?").run(order.id));
    if (order.data.total) (await postJournal(db, company, { scope: order.data.scope, projectId: order.data.projectId, description: `Sale ${order.id}`, lines: [{ account: 'receivables', debit: order.data.total }, { account: 'revenue', credit: order.data.total }] }));
    if (cogs) (await postJournal(db, company, { scope: order.data.scope, projectId: order.data.projectId, description: `COGS ${order.id}`, lines: [{ account: 'cogs', debit: cogs }, { account: 'inventory', credit: cogs }] }));
    return { id: order.id, status: 'SHIPPED', revenue: order.data.total, cogs, grossProfit: order.data.total - cogs };
  })));
  app.post('/v1/companies/:companyId/orders/:id/payments', { preHandler: auth }, async request => (await command(request, 'payments.write', 'order.payment', async company => {
    const order = (await getOrder(company.id, request.params.id));
    if (order.status !== 'SHIPPED') fail(409, 'invalid_order_state');
    const amount = integer(object(request.body).amount, 'amount', 1);
    const paid = (await db.prepare('SELECT COALESCE(SUM(amount),0) AS total FROM payments WHERE order_id=?').get(order.id)).total;
    if (paid + amount > order.data.total) fail(409, 'overpayment');
    const id = randomUUID();
    (await db.prepare('INSERT INTO payments VALUES(?,?,?,?,?)').run(id, company.id, order.id, amount, now()));
    (await postJournal(db, company, { scope: order.data.scope, projectId: order.data.projectId, description: `Payment ${id}`, lines: [{ account: 'cash', debit: amount }, { account: 'receivables', credit: amount }] }));
    if (paid + amount === order.data.total) (await db.prepare("UPDATE orders SET status='CLOSED' WHERE id=?").run(order.id));
    return { id, orderId: order.id, amount, outstanding: order.data.total - paid - amount };
  })));
  app.post('/v1/companies/:companyId/accounting/journal', { preHandler: auth }, async request => command(request, 'accounting.post', 'journal.post', async company => {
    const body = object(request.body);
    if(Array.isArray(body.lines)&&body.lines.some(line=>typeof line?.account==='string'&&line.account.startsWith('wallet:')))await access(request,'wallets.transact');
    const entry=await postJournal(db,company,{...body,description:`Manual: ${text(body.description,'description',490)}`});
    await registerManualWalletEntries(db,company.id,entry.id,entry.lines);return entry;
  }));
  app.get('/v1/companies/:companyId/accounting/journal', { preHandler: auth }, async request => {
    (await access(request, 'accounting.read'));
    const selected=request.query.projectId;
    if(selected!==undefined && selected!=='unassigned')await projectReference(db,request.params.companyId,selected);
    const filter=selected===undefined?'':' AND project_id IS NOT DISTINCT FROM ?';
    const from=businessDate(request.query.from??'0001-01-01'),to=businessDate(request.query.to??'9999-12-31');
    if(from>to)fail(400,'invalid_date_range');
    const ledger=request.query.scope===undefined?null:scope(request.query.scope),account=request.query.account===undefined?null:text(request.query.account,'account',64);
    const rows=await db.prepare(`SELECT * FROM journal j WHERE company_id=? AND id>?${filter} AND business_date>=? AND business_date<=?${ledger?" AND (scope=? OR scope='BOTH')":''}${account?' AND EXISTS (SELECT 1 FROM journal_lines l WHERE l.entry_id=j.id AND l.account=?)':''} ORDER BY id LIMIT ?`)
      .all(request.params.companyId,request.query.after??'',...(selected===undefined?[]:[selected==='unassigned'?null:selected]),from,to,...(ledger?[ledger]:[]),...(account?[account]:[]),pageLimit(request.query));
    return {items:rows.map(row=>({...row,lines:JSON.parse(row.lines)})),nextCursor:rows.length===pageLimit(request.query)?rows.at(-1).id:null};
  });
  app.get('/v1/companies/:companyId/accounting/trial-balance', { preHandler: auth }, async request => {
    (await access(request, 'accounting.read'));
    const selectedScope = scope(request.query.scope);
    const from=businessDate(request.query.from??'0001-01-01'),to=businessDate(request.query.to??'9999-12-31');
    if(from>to)fail(400,'invalid_date_range');
    const project=request.query.projectId;
    if(project!==undefined&&project!=='unassigned')await projectReference(db,request.params.companyId,project);
    const rows=await db.prepare(`SELECT l.account,
      sum(CASE WHEN j.business_date<? THEN l.debit-l.credit ELSE 0 END) AS opening,
      sum(CASE WHEN j.business_date>=? THEN l.debit ELSE 0 END) AS debit,
      sum(CASE WHEN j.business_date>=? THEN l.credit ELSE 0 END) AS credit,
      sum(l.debit-l.credit) AS balance FROM journal_lines l JOIN journal j ON j.id=l.entry_id
      WHERE j.company_id=? AND (j.scope=? OR j.scope='BOTH') AND j.business_date<=?${project===undefined?'':' AND j.project_id IS NOT DISTINCT FROM ?'}
      GROUP BY l.account ORDER BY l.account`).all(from,from,from,request.params.companyId,selectedScope,to,...(project===undefined?[]:[project==='unassigned'?null:project]));
    return {scope:selectedScope,from,to,projectId:project??null,accounts:rows};
  });
  app.get('/v1/companies/:companyId/audit', { preHandler: auth }, async request => {
    (await access(request, 'audit.read'));
    const after = integer(Number(request.query.after ?? 0), 'after');
    return { items: (await db.prepare('SELECT * FROM audit WHERE company_id=? AND sequence>? ORDER BY sequence LIMIT ?').all(request.params.companyId, after, pageLimit(request.query))) };
  });
  app.post('/v1/companies/:companyId/files', { preHandler: auth }, async request => {
    (await access(request, 'files.write'));
    const part = await request.file();
    if (!part) fail(400, 'file_required');
    // Downloads always use attachment and octet-stream. User MIME is metadata only.
    const data = await part.toBuffer(), id = randomUUID();
    await writeFile(resolve(fileDir, id), data, { flag: 'wx', mode: 0o600 });
    try {
      (await transaction(db, async () => {
        (await db.prepare('INSERT INTO files VALUES(?,?,?,?,?,?)').run(id, request.params.companyId, text(part.filename.replace(/[\\/\x00-\x1F]/g,'_'), 'filename', 255), part.mimetype, data.length, now()));
        (await audit(request, 'file.upload', id));
      }));
    } catch (error) { await unlink(resolve(fileDir, id)); throw error; }
    return { id, size: data.length };
  });
  app.get('/v1/companies/:companyId/files/:id', { preHandler: auth }, async (request, reply) => {
    (await access(request, 'files.read'));
    const file = (await db.prepare('SELECT * FROM files WHERE company_id=? AND id=?').get(request.params.companyId, request.params.id));
    if (!file) fail(404, 'file_not_found');
    reply.type('application/octet-stream').header('Content-Disposition', `attachment; filename*=UTF-8''${encodeURIComponent(file.name)}`);
    return reply.send(createReadStream(resolve(fileDir, file.id)));
  });
  registerEmployeeRoutes(app,{db,auth,access,command,pageLimit,object});
  registerAssetRoutes(app,{db,auth,access,command,pageLimit,object});
  const commercial=registerCommercialRoutes(app, { db, auth, access, command, pageLimit, object });
  registerBankRoutes(app, { db, auth, access, command, pageLimit, object, ...commercial });
  registerBusinessRoutes(app, { db, auth, access, command, pageLimit, object, audit });
  if (options.webRoot) await app.register(staticFiles, {root:resolve(options.webRoot),dotfiles:'deny',index:'index.html',cacheControl:true,maxAge:0});
  await app.ready();
  return app;
}
