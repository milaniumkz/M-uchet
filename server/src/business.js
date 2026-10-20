import { registerProjectRoutes } from './projects.js';
import { randomUUID } from 'node:crypto';
import { fail, integer, scope, text, businessDate } from './security.js';
import { allocate, postJournal, orderInput, normalizeLines, projectReference } from './accounting.js';
import { accountReference } from './legal.js';

const now = () => new Date().toISOString();
export function registerBusinessRoutes(app, { db, auth, access, command, pageLimit, object }) {
  const base = '/v1/companies/:companyId';
  const route = (method, path, handler) => app.route({ method, url: base + path, preHandler: auth, handler });
  const wallet = async (companyId, id) => {
    const row = (await db.prepare('SELECT * FROM wallets WHERE company_id=? AND id=?').get(companyId, text(id, 'walletId')));
    if (!row) fail(404, 'wallet_not_found'); return row;
  };
  const applyWallet = async (companyId, id, amount, kind, reference) => {
    const row = (await wallet(companyId, id));
    integer(Math.abs(amount), 'amount', 1);
    if (row.balance + amount < 0) fail(409, 'insufficient_funds');
    integer(row.balance + amount, 'wallet_balance');
    (await db.prepare('UPDATE wallets SET balance=balance+? WHERE id=?').run(amount, id));
    const entryId = randomUUID();
    (await db.prepare('INSERT INTO wallet_entries VALUES(?,?,?,?,?,?,?)').run(entryId, companyId, id, amount, kind, reference, now()));
    return { ...row, balance: row.balance + amount };
  };
  const requireReference = async (companyId, kind, id) => {
    if (!(await db.prepare('SELECT 1 FROM documents WHERE company_id=? AND kind=? AND id=?').get(companyId, kind, text(id, 'referenceId')))) fail(404, 'catalog_reference_not_found');
  };
  const journal = async (company, ledgerScope, description, debit, credit, amount, projectId = null) => {
    if (amount) return (await postJournal(db, company, { scope: ledgerScope, projectId, description, lines: [{ account: debit, debit: amount }, { account: credit, credit: amount }] }));
  };
  registerProjectRoutes({ route, db, access, command, object });
  route('GET','/accounting/chart',async request=>{
    const company=await access(request,'accounting.read');
    return accountReference(request.query.asOf??businessDate(undefined,company.timezone));
  });

  route('GET', '/wallets', async request => {
    (await access(request, 'wallets.read'));
    return { items: (await db.prepare('SELECT * FROM wallets WHERE company_id=? AND id>? ORDER BY id LIMIT ?').all(request.params.companyId, request.query.after ?? '', pageLimit(request.query))) };
  });
  route('POST', '/wallets', async request => (await command(request, 'wallets.write', 'wallet.create', async company => {
    const body = object(request.body), id = randomUUID();
    const name = text(body.name, 'name'), ledgerScope = scope(body.scope);
    (await db.prepare('INSERT INTO wallets VALUES(?,?,?,?,0)').run(id, company.id, name, ledgerScope));
    return { id, name, scope: ledgerScope, balance: 0, currency: company.currency };
  })));
  route('GET', '/wallets/:id/entries', async request => {
    (await access(request, 'wallets.read')); (await wallet(request.params.companyId, request.params.id));
    return { items: (await db.prepare('SELECT * FROM wallet_entries WHERE company_id=? AND wallet_id=? AND id>? ORDER BY id LIMIT ?').all(request.params.companyId, request.params.id, request.query.after ?? '', pageLimit(request.query))) };
  });
  route('POST', '/wallets/:id/transactions', async request => (await command(request, 'wallets.transact', 'wallet.transaction', async company => {
    const body = object(request.body), amount = integer(body.amount, 'amount', 1), type = body.type;
    if (!['INCOME','EXPENSE','CAPITAL'].includes(type)) fail(400, 'invalid_transaction_type');
    const row = (await wallet(company.id, request.params.id)), id = randomUUID();
    const description = text(body.description, 'description', 500);
    const result = (await applyWallet(company.id, row.id, type === 'EXPENSE' ? -amount : amount, type, id));
    const account = `wallet:${row.id}`;
    if (type === 'EXPENSE') (await journal(company, row.scope, description, 'expenses', account, amount, body.projectId));
    else (await journal(company, row.scope, description, account, type === 'CAPITAL' ? 'capital' : 'revenue', amount, body.projectId));
    return { id, walletId: row.id, balance: result.balance, amount, type };
  })));
  route('POST', '/wallet-transfers', async request => (await command(request, 'wallets.transact', 'wallet.transfer', async company => {
    const body = object(request.body), amount = integer(body.amount, 'amount', 1);
    const source = (await wallet(company.id, body.sourceWalletId)), target = (await wallet(company.id, body.targetWalletId));
    if (source.id === target.id || source.scope !== target.scope) fail(400, 'incompatible_wallets');
    const id = randomUUID();
    (await applyWallet(company.id, source.id, -amount, 'TRANSFER_OUT', id));
    (await applyWallet(company.id, target.id, amount, 'TRANSFER_IN', id));
    (await journal(company, source.scope, `Transfer ${id}`, `wallet:${target.id}`, `wallet:${source.id}`, amount));
    return { id, amount, sourceWalletId: source.id, targetWalletId: target.id };
  })));

  route('POST', '/inventory/movements', async request => (await command(request, 'inventory.move', 'inventory.move', async company => {
    const body = object(request.body), ledgerScope = scope(body.scope);
    const productId = text(body.productId, 'productId'), sourceId = text(body.sourceWarehouseId, 'sourceWarehouseId');
    const targetId = text(body.targetWarehouseId, 'targetWarehouseId'), quantity = integer(body.quantity, 'quantity', 1);
    if (sourceId === targetId) fail(400, 'same_warehouse');
    for (const warehouseId of [sourceId, targetId]) (await requireReference(company.id, 'warehouses', warehouseId));
    (await requireReference(company.id, 'nomenklatura', productId));
    const allocations = (await allocate(db, company.id, { productId, warehouseId: sourceId, quantity }, ledgerScope));
    let cost = 0;
    const id = randomUUID();
    for (const allocation of allocations) {
      (await db.prepare('UPDATE batches SET quantity=quantity-? WHERE id=?').run(allocation.quantity, allocation.batchId));
      (await db.prepare('INSERT INTO batches(id,company_id,product_id,warehouse_id,scope,quantity,reserved,unit_cost,created_at) VALUES(?,?,?,?,?,?,0,?,?)').run(randomUUID(), company.id, productId, targetId, ledgerScope, allocation.quantity, allocation.unitCost, now()));
      cost += allocation.quantity * allocation.unitCost;
    }
    integer(cost, 'movement_cost');
    const data = { id, productId, sourceWarehouseId: sourceId, targetWarehouseId: targetId, quantity, cost, scope: ledgerScope };
    (await db.prepare('INSERT INTO movements VALUES(?,?,?,?,?)').run(id, company.id, 'TRANSFER', JSON.stringify(data), now()));
    return data;
  })));
  route('POST', '/inventory/writeoffs', async request => (await command(request, 'inventory.writeoff', 'inventory.writeoff', async company => {
    const body = object(request.body), ledgerScope = scope(body.scope), reason = text(body.reason, 'reason', 500);
    const item = { productId: text(body.productId, 'productId'), warehouseId: text(body.warehouseId, 'warehouseId'), quantity: integer(body.quantity, 'quantity', 1) };
    const allocations = (await allocate(db, company.id, item, ledgerScope));
    const id = randomUUID(); let cost = 0;
    for (const allocation of allocations) {
      (await db.prepare('UPDATE batches SET quantity=quantity-? WHERE id=?').run(allocation.quantity, allocation.batchId));
      cost += allocation.quantity * allocation.unitCost;
    }
    integer(cost, 'writeoff_cost');
    (await journal(company, ledgerScope, `Writeoff ${id}: ${reason}`, 'inventory_loss', 'inventory', cost, body.projectId));
    const data = { id, ...item, reason, cost, scope: ledgerScope };
    (await db.prepare('INSERT INTO movements VALUES(?,?,?,?,?)').run(id, company.id, 'WRITEOFF', JSON.stringify(data), now()));
    return data;
  })));
  route('GET', '/inventory/movements', async request => {
    (await access(request, 'inventory.read'));
    return { items: (await db.prepare('SELECT * FROM movements WHERE company_id=? AND id>? ORDER BY id LIMIT ?').all(request.params.companyId, request.query.after ?? '', pageLimit(request.query))).map(r => ({ ...r, data: JSON.parse(r.data) })) };
  });

  route('POST', '/debts', async request => (await command(request, 'debts.write', 'debt.create', async company => {
    const body = object(request.body), amount = integer(body.amount, 'amount', 1), ledgerScope = scope(body.scope);
    if (!['AR','AP'].includes(body.type)) fail(400, 'invalid_debt_type');
    const counterpartyId = text(body.counterpartyId, 'counterpartyId');
    (await requireReference(company.id, body.type === 'AR' ? 'clients' : 'suppliers', counterpartyId));
    let dueDate = null;
    if (body.dueDate !== undefined) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(body.dueDate) || !Number.isFinite(Date.parse(body.dueDate)) || new Date(body.dueDate).toISOString().slice(0,10) !== body.dueDate) fail(400, 'invalid_due_date');
      dueDate = body.dueDate;
    }
    const id = randomUUID();
    (await db.prepare('INSERT INTO debts VALUES(?,?,?,?,?,?,?,?,?)').run(id, company.id, body.type, counterpartyId, amount, amount, ledgerScope, dueDate, now()));
    await journal(company, ledgerScope, `Opening debt ${id}`, body.type === 'AR' ? 'receivables' : 'opening_balances', body.type === 'AR' ? 'opening_balances' : 'payables', amount);
    return { id, type: body.type, total: amount, remaining: amount, scope: ledgerScope, dueDate };
  })));
  route('GET', '/debts', async request => {
    (await access(request, 'debts.read'));
    return { items: (await db.prepare('SELECT * FROM debts WHERE company_id=? AND id>? ORDER BY id LIMIT ?').all(request.params.companyId, request.query.after ?? '', pageLimit(request.query))) };
  });
  route('POST', '/debts/:id/settlements', async request => (await command(request, 'debts.settle', 'debt.settle', async company => {
    const debt = (await db.prepare('SELECT * FROM debts WHERE company_id=? AND id=?').get(company.id, request.params.id));
    if (!debt) fail(404, 'debt_not_found');
    const body = object(request.body), amount = integer(body.amount, 'amount', 1), row = (await wallet(company.id, body.walletId));
    if (amount > debt.remaining) fail(409, 'overpayment');
    if (row.scope !== debt.scope) fail(400, 'incompatible_ledger_scope');
    const id = randomUUID();
    (await applyWallet(company.id, row.id, debt.type === 'AR' ? amount : -amount, 'DEBT_PAYMENT', id));
    (await db.prepare('UPDATE debts SET remaining=remaining-? WHERE id=?').run(amount, debt.id));
    (await db.prepare('INSERT INTO debt_payments VALUES(?,?,?,?,?,?)').run(id, company.id, debt.id, row.id, amount, now()));
    if (debt.type === 'AR') (await journal(company, debt.scope, `Debt payment ${id}`, `wallet:${row.id}`, 'receivables', amount));
    else (await journal(company, debt.scope, `Debt payment ${id}`, 'payables', `wallet:${row.id}`, amount));
    return { id, debtId: debt.id, remaining: debt.remaining - amount };
  })));
  route('GET', '/debts/:id/payments', async request => {
    (await access(request, 'debts.read'));
    if (!(await db.prepare('SELECT 1 FROM debts WHERE company_id=? AND id=?').get(request.params.companyId, request.params.id))) fail(404, 'debt_not_found');
    return { items: (await db.prepare('SELECT * FROM debt_payments WHERE company_id=? AND debt_id=? AND id>? ORDER BY id LIMIT ?').all(request.params.companyId, request.params.id, request.query.after ?? '', pageLimit(request.query))) };
  });

  route('POST', '/shifts', async request => (await command(request, 'shifts.write', 'shift.open', async company => {
    const body = object(request.body), row = (await wallet(company.id, body.walletId));
    if ((await db.prepare("SELECT 1 FROM cash_shifts WHERE wallet_id=? AND status='OPEN'").get(row.id))) fail(409, 'shift_already_open');
    const id = randomUUID();
    (await db.prepare("INSERT INTO cash_shifts VALUES(?,?,?,?,?,NULL,'OPEN',?,NULL)").run(id, company.id, row.id, request.user.id, row.balance, now()));
    return { id, walletId: row.id, opening: row.balance, status: 'OPEN' };
  })));
  route('POST', '/shifts/:id/close', async request => (await command(request, 'shifts.write', 'shift.close', async company => {
    const row = (await db.prepare('SELECT * FROM cash_shifts WHERE company_id=? AND id=?').get(company.id, request.params.id));
    if (!row) fail(404, 'shift_not_found');
    if (row.status !== 'OPEN') fail(409, 'shift_closed');
    if (row.user_id !== request.user.id && !(await db.prepare("SELECT 1 FROM memberships WHERE company_id=? AND user_id=? AND role='owner'").get(company.id, request.user.id))) fail(403, 'shift_owner_required');
    const counted = integer(object(request.body).countedAmount, 'countedAmount');
    const expected = (await wallet(company.id, row.wallet_id)).balance;
    (await db.prepare("UPDATE cash_shifts SET status='CLOSED',closing=?,closed_at=? WHERE id=?").run(counted, now(), row.id));
    return { id: row.id, status: 'CLOSED', countedAmount: counted, expectedAmount: expected, difference: counted - expected };
  })));
  route('GET', '/shifts', async request => {
    (await access(request, 'shifts.read'));
    return { items: (await db.prepare('SELECT * FROM cash_shifts WHERE company_id=? AND id>? ORDER BY id LIMIT ?').all(request.params.companyId, request.query.after ?? '', pageLimit(request.query))) };
  });

  route('POST', '/devices/:id/commands', async request => (await command(request, 'devices.command', 'device.command', async company => {
    (await requireReference(company.id, 'devices', request.params.id));
    const body = object(request.body);
    if (!['LOCK','UNLOCK','SYNC'].includes(body.command)) fail(400, 'invalid_device_command');
    const id = randomUUID();
    (await db.prepare("INSERT INTO device_commands VALUES(?,?,?,?,?,'PENDING',?,NULL)").run(id, company.id, request.params.id, body.command, '{}', now()));
    return { id, deviceId: request.params.id, command: body.command, status: 'PENDING' };
  })));
  route('GET', '/devices/:id/commands', async request => {
    (await access(request, 'devices.read')); (await requireReference(request.params.companyId, 'devices', request.params.id));
    return { items: (await db.prepare('SELECT * FROM device_commands WHERE company_id=? AND device_id=? AND id>? ORDER BY id LIMIT ?').all(request.params.companyId, request.params.id, request.query.after ?? '', pageLimit(request.query))) };
  });
  route('POST', '/devices/:id/commands/:commandId/acknowledge', async request => (await command(request, 'devices.command', 'device.acknowledge', async company => {
    const row = (await db.prepare('SELECT * FROM device_commands WHERE company_id=? AND device_id=? AND id=?').get(company.id, request.params.id, request.params.commandId));
    if (!row) fail(404, 'command_not_found');
    if (row.status !== 'PENDING') fail(409, 'command_not_pending');
    const status = object(request.body).status;
    if (!['SUCCEEDED','FAILED'].includes(status)) fail(400, 'invalid_command_status');
    (await db.prepare('UPDATE device_commands SET status=?,acknowledged_at=? WHERE id=?').run(status, now(), row.id));
    return { id: row.id, status };
  })));

  route('POST', '/accounting/journal/:id/reverse', async request => (await command(request, 'accounting.post', 'journal.reverse', async company => {
    const row = (await db.prepare('SELECT * FROM journal WHERE company_id=? AND id=?').get(company.id, request.params.id));
    if (!row) fail(404, 'journal_not_found');
    if ((await db.prepare('SELECT 1 FROM journal_reversals WHERE original_id=? OR reversal_id=?').get(row.id, row.id))) fail(409, 'journal_already_reversed');
    // Reversing generated journal entries independently would desynchronize stock/wallets/orders.
    if (!row.description.startsWith('Manual: ')) fail(409, 'business_command_reversal_required');
    const reason = text(object(request.body).reason, 'reason', 400);
    const result = (await postJournal(db, company, { scope: row.scope, projectId: row.project_id, description: `Reversal: ${reason}`, lines: JSON.parse(row.lines).map(line => ({ account: line.account, debit: line.credit, credit: line.debit })) }));
    (await db.prepare('INSERT INTO journal_reversals VALUES(?,?)').run(row.id, result.id));
    return { ...result, originalId: row.id };
  })));
  route('GET', '/reports/profit-loss', async request => {
    (await access(request, 'reports.read'));
    const ledgerScope = scope(request.query.scope);
    const date = (raw, fallback) => {
      if (raw === undefined) return fallback;
      if (!/^\d{4}-\d{2}-\d{2}$/.test(raw) || !Number.isFinite(Date.parse(raw)) || new Date(raw).toISOString().slice(0,10) !== raw) fail(400, 'invalid_report_date');
      return raw;
    };
    const from = date(request.query.from, '0001-01-01'), to = date(request.query.to, '9999-12-31');
    if (from > to) fail(400, 'invalid_date_range');
    const rows = (await db.prepare("SELECT lines FROM journal WHERE company_id=? AND (scope=? OR scope='BOTH') AND business_date>=? AND business_date<=?").all(request.params.companyId, ledgerScope, from, to));
    let revenue = 0, cogs = 0, expenses = 0;
    for (const row of rows) for (const line of JSON.parse(row.lines)) {
      if (line.account === 'revenue') revenue += line.credit - line.debit;
      if (line.account === 'cogs') cogs += line.debit - line.credit;
      if (['expenses','inventory_loss'].includes(line.account)) expenses += line.debit - line.credit;
    }
    for (const amount of [revenue,cogs,expenses,revenue-cogs-expenses]) if (!Number.isSafeInteger(amount)) fail(422, 'report_amount_overflow');
    return { scope: ledgerScope, from, to, revenue, cogs, grossProfit: revenue-cogs, expenses, netProfit: revenue-cogs-expenses };
  });
  for (const [operation,status,permission] of [['close','CLOSED','periods.close'],['reopen','OPEN','periods.reopen']]) {
    route('POST', `/periods/:month/${operation}`, async request => command(request, permission, `period.${operation}`, async company => {
      const month = request.params.month;
      if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) fail(400, 'invalid_period');
      const reason = text(object(request.body).reason, 'reason', 500);
      if (operation === 'close' && await db.prepare("SELECT 1 FROM orders WHERE company_id=? AND status='RESERVED' LIMIT 1").get(company.id)) fail(409, 'unfulfilled_reservations');
      await db.prepare('INSERT INTO accounting_periods VALUES(?,?,?,?,?) ON CONFLICT(company_id,month) DO UPDATE SET status=excluded.status,changed_by=excluded.changed_by,changed_at=excluded.changed_at').run(company.id,month,status,request.user.id,now());
      return { id: month, status, reason };
    }));
  }
  route('PUT','/wallets/:id',async request=>command(request,'wallets.write','wallet.edit',async company=>{
    const old=await wallet(company.id,request.params.id),body=object(request.body);
    const name=body.name===undefined?old.name:text(body.name,'name');
    const balance=body.balance===undefined?old.balance:integer(body.balance,'balance');
    if(balance!==old.balance)await access(request,'wallets.transact');
    // A direct balance edit is an explicit reconciled adjustment, never a silent rewrite of movements.
    await db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(company.id,'wallet',old.id,JSON.stringify(old),request.user.id);
    if(balance!==old.balance){
      const delta=balance-old.balance;
      await applyWallet(company.id,old.id,delta,'BALANCE_EDIT',old.id);
      await journal(company,old.scope,`Balance edit ${old.id}`,delta>0?`wallet:${old.id}`:'balance_corrections',delta>0?'balance_corrections':`wallet:${old.id}`,Math.abs(delta));
    }
    await db.prepare('UPDATE wallets SET name=? WHERE id=?').run(name,old.id);
    return {id:old.id,name,balance,scope:old.scope};
  }));
  route('PUT','/accounting/journal/:id',async request=>command(request,'accounting.edit','journal.edit',async company=>{
    const old=await db.prepare('SELECT * FROM journal WHERE company_id=? AND id=?').get(company.id,request.params.id);
    if(!old)fail(404,'journal_not_found');
    const body=object(request.body),reason=body.reason===undefined?'Owner requested edit':text(body.reason,'reason',500);
    await db.prepare("SELECT set_config('app.edit_reason',?,true)").get(reason);
    const replacement={id:old.id,projectId:await projectReference(db,company.id,Object.hasOwn(body,'projectId')?body.projectId:old.project_id),scope:scope(body.scope??old.scope),description:text(body.description??old.description,'description',500),businessDate:businessDate(body.businessDate??old.business_date,company.timezone),lines:normalizeLines({lines:body.lines??JSON.parse(old.lines)})};
    await db.prepare('UPDATE journal SET scope=?,description=?,lines=?,business_date=?,project_id=? WHERE id=?').run(replacement.scope,replacement.description,JSON.stringify(replacement.lines),replacement.businessDate,replacement.projectId,old.id);
    await db.prepare('DELETE FROM journal_lines WHERE entry_id=?').run(old.id);
    for(const [position,line]of replacement.lines.entries())await db.prepare('INSERT INTO journal_lines VALUES(?,?,?,?,?)').run(old.id,position,line.account,line.debit,line.credit);
    return {...replacement,id:old.id,reason};
  }));
  route('GET','/accounting/journal/:id/history',async request=>{
    await access(request,'accounting.read');
    if(!await db.prepare('SELECT 1 FROM journal WHERE company_id=? AND id=?').get(request.params.companyId,request.params.id))fail(404,'journal_not_found');
    return {items:await db.prepare('SELECT * FROM journal_history WHERE entry_id=? ORDER BY revision').all(request.params.id)};
  });
  route('PUT','/orders/:id',async request=>command(request,'orders.edit','order.edit',async company=>{
    const old=await db.prepare('SELECT * FROM orders WHERE company_id=? AND id=?').get(company.id,request.params.id);
    if(!old)fail(404,'order_not_found');
    const previous=JSON.parse(old.data),next=await orderInput(db,company.id,{...previous,...object(request.body)});
    await db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(company.id,'order',old.id,JSON.stringify(old),request.user.id);
    const shipped=['SHIPPED','CLOSED'].includes(old.status);
    let oldCost=0,newCost=0;
    if(old.status==='RESERVED'){
      for(const r of await db.prepare('SELECT * FROM reservations WHERE order_id=?').all(old.id))await db.prepare('UPDATE batches SET reserved=reserved-? WHERE id=?').run(r.quantity,r.batch_id);
      await db.prepare('DELETE FROM reservations WHERE order_id=?').run(old.id);
    }
    if(shipped){
      for(const r of await db.prepare('SELECT * FROM shipment_allocations WHERE order_id=?').all(old.id)){
        await db.prepare('UPDATE batches SET quantity=quantity+? WHERE id=?').run(r.quantity,r.batch_id);oldCost+=r.quantity*r.unit_cost;
      }
      await db.prepare('DELETE FROM shipment_allocations WHERE order_id=?').run(old.id);
    }
    if(shipped||old.status==='RESERVED')for(const item of next.items)for(const a of await allocate(db,company.id,item,next.scope)){
      if(shipped){
        await db.prepare('UPDATE batches SET quantity=quantity-? WHERE id=?').run(a.quantity,a.batchId);
        await db.prepare('INSERT INTO shipment_allocations VALUES(?,?,?,?)').run(old.id,a.batchId,a.quantity,a.unitCost);newCost+=a.quantity*a.unitCost;
      }else{
        await db.prepare('UPDATE batches SET reserved=reserved+? WHERE id=?').run(a.quantity,a.batchId);
        await db.prepare('INSERT INTO reservations VALUES(?,?,?)').run(old.id,a.batchId,a.quantity);
      }
    }
    let status=old.status;
    if(shipped){
      const paid=(await db.prepare('SELECT COALESCE(SUM(amount),0) AS total FROM payments WHERE order_id=?').get(old.id)).total;
      const oldCredit=previous.customerCredit??0,newCredit=Math.max(0,paid-next.total);
      const adjust=async(ledgerScope,debit,credit,delta,projectId)=>{if(delta)await journal(company,ledgerScope,`Order edit ${old.id}`,delta>0?debit:credit,delta>0?credit:debit,Math.abs(delta),projectId);};
      if(next.scope===previous.scope && next.projectId===(previous.projectId??null)){
        await adjust(next.scope,'receivables','revenue',next.total-previous.total,next.projectId);
        await adjust(next.scope,'cogs','inventory',newCost-oldCost,next.projectId);
        await adjust(next.scope,'receivables','customer_advances',newCredit-oldCredit,next.projectId);
      }else{
        await adjust(previous.scope,'receivables','revenue',-previous.total,previous.projectId);await adjust(previous.scope,'cogs','inventory',-oldCost,previous.projectId);
        await adjust(previous.scope,'cash','receivables',-paid,previous.projectId);await adjust(previous.scope,'receivables','customer_advances',-oldCredit,previous.projectId);
        await adjust(next.scope,'receivables','revenue',next.total,next.projectId);await adjust(next.scope,'cogs','inventory',newCost,next.projectId);
        await adjust(next.scope,'cash','receivables',paid,next.projectId);await adjust(next.scope,'receivables','customer_advances',newCredit,next.projectId);
      }
      next.customerCredit=newCredit;status=paid>=next.total?'CLOSED':'SHIPPED';
    }
    await db.prepare('UPDATE orders SET data=?,status=? WHERE id=?').run(JSON.stringify(next),status,old.id);
    return {id:old.id,status,...next,cogs:shipped?newCost:undefined};
  }));
  route('GET','/orders/:id/history',async request=>{
    await access(request,'orders.read');
    return {items:await db.prepare("SELECT * FROM entity_history WHERE company_id=? AND kind='order' AND entity_id=? ORDER BY revision").all(request.params.companyId,request.params.id)};
  });
}
