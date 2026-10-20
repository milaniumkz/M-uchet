import { projectOrderPayments } from './order-payments.js';
import { registerProjectRoutes } from './projects.js';
import { randomUUID } from 'node:crypto';
import { fail, integer, scope, text, businessDate, bankIban } from './security.js';
import { allocate, postJournal, orderInput, normalizeLines, projectReference, syncWalletBalances, registerManualWalletEntries } from './accounting.js';
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
    const entryId = randomUUID();
    (await db.prepare('INSERT INTO wallet_entries(id,company_id,wallet_id,amount,kind,reference_id,created_at) VALUES(?,?,?,?,?,?,?)').run(entryId, companyId, id, amount, kind, reference, now()));
    return { ...row, entryId, balance: row.balance + amount };
  };
  const requireReference = async (companyId, kind, id) => {
    if (!(await db.prepare('SELECT 1 FROM documents WHERE company_id=? AND kind=? AND id=?').get(companyId, kind, text(id, 'referenceId')))) fail(404, 'catalog_reference_not_found');
  };
  const journal = async (company, ledgerScope, description, debit, credit, amount, projectId = null, date) => {
    if (amount) return (await postJournal(db, company, { scope: ledgerScope, projectId, businessDate:date, description, lines: [{ account: debit, debit: amount }, { account: credit, credit: amount }] }));
  };
  registerProjectRoutes({ route, db, access, command, object });
  route('GET','/settings',async request=>{
    const company=await access(request,'organization.read');
    const row=await db.prepare('SELECT * FROM company_settings WHERE company_id=?').get(company.id);
    return row??{company_id:company.id,legal_name:company.name,identifier:null,legal_form:null,tax_regime:null,vat_registered:false,version:0};
  });
  route('PUT','/settings',request=>command(request,'organization.write','company.settings',async company=>{
    const body=object(request.body);
    const old=await db.prepare('SELECT * FROM company_settings WHERE company_id=?').get(company.id);
    if(body.version!==(old?.version??0))fail(409,'version_conflict');
    if(!['TOO','IP'].includes(body.legalForm))fail(400,'invalid_legal_form');
    if(!['GENERAL','SIMPLIFIED'].includes(body.taxRegime))fail(400,'invalid_tax_regime');
    if(typeof body.vatRegistered!=='boolean')fail(400,'invalid_vat_registration');
    const identifier=body.identifier===null||body.identifier===''?null:text(body.identifier,'identifier',12);
    if(identifier!==null&&!/^[0-9]{12}$/.test(identifier))fail(400,'invalid_identifier');
    const name=text(body.legalName,'legalName',250),version=(old?.version??0)+1;
    if(old)await db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(company.id,'company_settings',company.id,JSON.stringify(old),request.user.id);
    const optional=(key,column,max=250)=>{const value=body[key]??old?.[column]??'';if(typeof value!=='string'||value.length>max)fail(400,`invalid_${key}`);return value.trim();};
    const address=optional('legalAddress','legal_address',500),iban=bankIban(optional('bankIban','bank_iban',40)),bic=optional('bankBic','bank_bic',11).toUpperCase(),director=optional('directorName','director_name'),accountant=optional('accountantName','accountant_name');
    if(bic&&!/^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$/.test(bic))fail(400,'invalid_bank_bic');
    await db.prepare(`INSERT INTO company_settings(company_id,legal_name,identifier,legal_form,tax_regime,vat_registered,version,legal_address,bank_iban,bank_bic,director_name,accountant_name) VALUES(?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(company_id) DO UPDATE SET legal_name=excluded.legal_name,identifier=excluded.identifier,legal_form=excluded.legal_form,tax_regime=excluded.tax_regime,vat_registered=excluded.vat_registered,version=excluded.version,legal_address=excluded.legal_address,bank_iban=excluded.bank_iban,bank_bic=excluded.bank_bic,director_name=excluded.director_name,accountant_name=excluded.accountant_name`).run(company.id,name,identifier,body.legalForm,body.taxRegime,body.vatRegistered,version,address,iban,bic,director,accountant);
    return await db.prepare('SELECT * FROM company_settings WHERE company_id=?').get(company.id);
  }));
  route('GET','/accounting/chart',async request=>{
    const company=await access(request,'accounting.read');
    return accountReference(request.query.asOf??businessDate(undefined,company.timezone));
  });

  const assetSource=async(companyId,id)=>db.prepare('SELECT asset_id FROM asset_postings WHERE company_id=? AND journal_id=? LIMIT 1').get(companyId,id);
  const commercialSource=async(companyId,id)=>db.prepare(`SELECT document_id FROM commercial_postings WHERE company_id=? AND journal_id=? UNION SELECT document_id FROM commercial_payments WHERE company_id=? AND journal_id=? UNION SELECT p.document_id FROM commercial_payments p JOIN wallet_entries e ON e.reference_id=p.id WHERE p.company_id=? AND e.journal_id=? LIMIT 1`).get(companyId,id,companyId,id,companyId,id);
  const orderSource=async(companyId,id)=>db.prepare('SELECT order_id FROM order_postings WHERE company_id=? AND journal_id=? UNION SELECT order_id FROM payments WHERE company_id=? AND journal_id=? UNION SELECT order_id FROM order_settlement_postings WHERE company_id=? AND journal_id=? UNION SELECT p.order_id FROM payments p JOIN wallet_entries e ON e.company_id=p.company_id AND e.reference_id=p.id WHERE p.company_id=? AND e.journal_id=? LIMIT 1').get(companyId,id,companyId,id,companyId,id,companyId,id);

  route('GET', '/wallets', async request => {
    const company=await access(request,'wallets.read');
    return { businessDate:businessDate(undefined,company.timezone),items: (await db.prepare('SELECT * FROM wallets WHERE company_id=? AND id>? ORDER BY id LIMIT ?').all(request.params.companyId, request.query.after ?? '', pageLimit(request.query))) };
  });
  route('POST', '/wallets', async request => (await command(request, 'wallets.write', 'wallet.create', async company => {
    const body = object(request.body), id = randomUUID();
    const name = text(body.name, 'name'), ledgerScope = scope(body.scope);
    (await db.prepare('INSERT INTO wallets VALUES(?,?,?,?,0)').run(id, company.id, name, ledgerScope));
    return { id, name, scope: ledgerScope, balance: 0, currency: company.currency };
  })));
  route('GET', '/wallets/:id/entries', async request => {
    (await access(request, 'wallets.read')); (await wallet(request.params.companyId, request.params.id));
    const project=request.query.projectId;
    if(project!==undefined&&project!=='unassigned')await projectReference(db,request.params.companyId,project);
    const filter=project===undefined?'':' AND j.project_id IS NOT DISTINCT FROM ?';
    const rows=await db.prepare(`SELECT e.*,j.project_id,j.description,j.business_date FROM wallet_entries e LEFT JOIN journal j ON j.id=e.journal_id WHERE e.company_id=? AND e.wallet_id=? AND e.id>?${filter} ORDER BY e.id LIMIT ?`).all(request.params.companyId,request.params.id,request.query.after??'',...(project===undefined?[]:[project==='unassigned'?null:project]),pageLimit(request.query));
    return {items:rows,nextCursor:rows.length===pageLimit(request.query)?rows.at(-1).id:null};
  });
  route('POST', '/wallets/:id/transactions', async request => (await command(request, 'wallets.transact', 'wallet.transaction', async company => {
    const body = object(request.body), amount = integer(body.amount, 'amount', 1), type = body.type;
    if (!['INCOME','EXPENSE','CAPITAL'].includes(type)) fail(400, 'invalid_transaction_type');
    const row = (await wallet(company.id, request.params.id)), id = randomUUID();
    const description = text(body.description, 'description', 500);
    const result = (await applyWallet(company.id, row.id, type === 'EXPENSE' ? -amount : amount, type, id));
    const account = `wallet:${row.id}`;
    const posting = type === 'EXPENSE'
      ? await journal(company, row.scope, description, 'expenses', account, amount, body.projectId, body.businessDate)
      : await journal(company, row.scope, description, account, type === 'CAPITAL' ? 'capital' : 'revenue', amount, body.projectId, body.businessDate);
    await db.prepare('UPDATE wallet_entries SET journal_id=? WHERE id=?').run(posting.id,result.entryId);
    return { id, entryId:result.entryId, walletId: row.id, balance: result.balance, amount, type };
  })));
  route('PUT','/wallets/:id/entries/:entryId',request=>command(request,'wallets.transact','wallet.transaction.edit',async company=>{
    const body=object(request.body),row=await wallet(company.id,request.params.id);
    const old=await db.prepare('SELECT * FROM wallet_entries WHERE company_id=? AND wallet_id=? AND id=?').get(company.id,row.id,request.params.entryId);
    if(!old)fail(404,'wallet_entry_not_found');
    if(!['INCOME','EXPENSE','CAPITAL'].includes(old.kind)||!old.journal_id)fail(422,'transaction_requires_reconciliation');
    const type=body.type??old.kind,amount=integer(body.amount??Math.abs(old.amount),'amount',1);
    if(!['INCOME','EXPENSE','CAPITAL'].includes(type))fail(400,'invalid_transaction_type');
    const signed=type==='EXPENSE'?-amount:amount,balance=row.balance-old.amount+signed;
    if(balance<0)fail(409,'insufficient_funds');integer(balance,'wallet_balance');
    const previous=await db.prepare('SELECT * FROM journal WHERE company_id=? AND id=?').get(company.id,old.journal_id);
    const projectId=await projectReference(db,company.id,Object.hasOwn(body,'projectId')?body.projectId:previous.project_id);
    const description=text(body.description??previous.description,'description',500),reason=text(body.reason??'Wallet transaction edit','reason',500);
    const date=businessDate(body.businessDate??previous.business_date,company.timezone),account=`wallet:${row.id}`;
    const lines=type==='EXPENSE'?[{account:'expenses',debit:amount,credit:0},{account,debit:0,credit:amount}]:[{account,debit:amount,credit:0},{account:type==='CAPITAL'?'capital':'revenue',debit:0,credit:amount}];
    await db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(company.id,'wallet_entry',old.id,JSON.stringify({entry:old,walletBalance:row.balance}),request.user.id);
    await db.prepare("SELECT set_config('app.edit_reason',?,true)").get(reason);
    await db.prepare('UPDATE wallet_entries SET amount=?,kind=? WHERE id=?').run(signed,type,old.id);
    await db.prepare('UPDATE journal SET description=?,lines=?,business_date=?,project_id=? WHERE id=?').run(description,JSON.stringify(lines),date,projectId,previous.id);
    await db.prepare('DELETE FROM journal_lines WHERE entry_id=?').run(previous.id);
    for(const [position,line]of lines.entries())await db.prepare('INSERT INTO journal_lines VALUES(?,?,?,?,?)').run(previous.id,position,line.account,line.debit,line.credit);
    await syncWalletBalances(db,company.id,lines);
    return {id:old.id,walletId:row.id,amount,type,balance,projectId,businessDate:date,description};
  }));
  route('POST', '/wallet-transfers', async request => (await command(request, 'wallets.transact', 'wallet.transfer', async company => {
    const body = object(request.body), amount = integer(body.amount, 'amount', 1);
    const source = (await wallet(company.id, body.sourceWalletId)), target = (await wallet(company.id, body.targetWalletId));
    if (source.id === target.id || source.scope !== target.scope) fail(400, 'incompatible_wallets');
    const id = randomUUID();
    (await applyWallet(company.id, source.id, -amount, 'TRANSFER_OUT', id));
    (await applyWallet(company.id, target.id, amount, 'TRANSFER_IN', id));
    const posting=await journal(company,source.scope,text(body.description??'Перевод между денежными счетами','description',500),`wallet:${target.id}`,`wallet:${source.id}`,amount,null,body.businessDate);
    await db.prepare("UPDATE wallet_entries SET journal_id=? WHERE company_id=? AND reference_id=? AND kind IN ('TRANSFER_OUT','TRANSFER_IN')").run(posting.id,company.id,id);
    return { id, amount, sourceWalletId: source.id, targetWalletId: target.id };
  })));

  const getTransfer=async(companyId,id)=>{
    const rows=await db.prepare("SELECT * FROM wallet_entries WHERE company_id=? AND reference_id=? AND kind IN ('TRANSFER_IN','TRANSFER_OUT')").all(companyId,text(id,'transferId'));
    if(rows.length!==2||!rows[0].journal_id||rows[0].journal_id!==rows[1].journal_id)fail(422,'transaction_requires_reconciliation');
    const source=rows.find(r=>r.amount<0),target=rows.find(r=>r.amount>0);
    if(!source||!target||source.amount+target.amount!==0)fail(422,'transaction_requires_reconciliation');
    const entry=await db.prepare('SELECT * FROM journal WHERE company_id=? AND id=?').get(companyId,source.journal_id);
    const lines=JSON.parse(entry.lines);if(lines.length!==2||lines.some(l=>!l.account.startsWith('wallet:')))fail(422,'transaction_requires_reconciliation');
    const revision=(await db.prepare('SELECT count(*) AS n FROM journal_history WHERE entry_id=?').get(entry.id)).n;
    return {id,revision,sourceWalletId:source.wallet_id,targetWalletId:target.wallet_id,amount:target.amount,businessDate:entry.business_date,description:entry.description,scope:entry.scope,journalId:entry.id,sourceEntryId:source.id,targetEntryId:target.id,projectId:entry.project_id};
  };
  route('GET','/wallet-transfers/:id',async request=>{const company=await access(request,'wallets.read');return getTransfer(company.id,request.params.id);});
  route('GET','/wallet-transfers/:id/history',async request=>{
    const company=await access(request,'wallets.read'),transfer=await getTransfer(company.id,request.params.id);
    const rows=await db.prepare('SELECT h.*,u.name AS actor_name FROM journal_history h LEFT JOIN users u ON u.id=h.actor_id WHERE h.entry_id=? ORDER BY h.revision DESC LIMIT 200').all(transfer.journalId);
    return {items:rows.map(row=>{const lines=JSON.parse(row.snapshot.lines),simple=lines.length===2&&lines.every(l=>l.account.startsWith('wallet:'));return {...row,snapshot:{...row.snapshot,amount:simple?lines.reduce((sum,line)=>sum+line.debit,0):null}};})};
  });
  route('PUT','/wallet-transfers/:id',request=>command(request,'wallets.transact','wallet.transfer.edit',async company=>{
    const old=await getTransfer(company.id,request.params.id),body=object(request.body),amount=integer(body.amount,'amount',1);
    if(body.expectedRevision!==undefined&&body.expectedRevision!==old.revision)fail(409,'version_conflict');
    const source=await wallet(company.id,body.sourceWalletId),target=await wallet(company.id,body.targetWalletId);
    if(source.id===target.id||source.scope!==target.scope)fail(400,'incompatible_wallets');
    const date=businessDate(body.businessDate??old.businessDate,company.timezone),description=text(body.description??old.description,'description',500),reason=text(body.reason??'Исправление перевода','reason',500);
    const previous=await db.prepare('SELECT * FROM journal WHERE company_id=? AND id=?').get(company.id,old.journalId);
    const lines=[{account:`wallet:${target.id}`,debit:amount,credit:0},{account:`wallet:${source.id}`,debit:0,credit:amount}];
    await db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(company.id,'wallet_transfer',old.id,JSON.stringify({...old,reason}),request.user.id);
    await db.prepare("SELECT set_config('app.edit_reason',?,true)").get(reason);
    await db.prepare('UPDATE journal SET scope=?,description=?,business_date=?,lines=? WHERE id=?').run(source.scope,description,date,JSON.stringify(lines),old.journalId);
    await db.prepare('DELETE FROM journal_lines WHERE entry_id=?').run(old.journalId);
    for(const [index,line]of lines.entries())await db.prepare('INSERT INTO journal_lines VALUES(?,?,?,?,?)').run(old.journalId,index,line.account,line.debit,line.credit);
    await db.prepare("UPDATE wallet_entries SET wallet_id=?,amount=?,kind='TRANSFER_OUT' WHERE id=?").run(source.id,-amount,old.sourceEntryId);
    await db.prepare("UPDATE wallet_entries SET wallet_id=?,amount=?,kind='TRANSFER_IN' WHERE id=?").run(target.id,amount,old.targetEntryId);
    await syncWalletBalances(db,company.id,[...JSON.parse(previous.lines),...lines]);return getTransfer(company.id,old.id);
  }));

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
    (await journal(company, ledgerScope, `Writeoff ${id}: ${reason}`, 'inventory_loss', 'inventory', cost, body.projectId, body.businessDate));
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
    await journal(company, ledgerScope, `Opening debt ${id}`, body.type === 'AR' ? 'receivables' : 'opening_balances', body.type === 'AR' ? 'opening_balances' : 'payables', amount,body.projectId,body.businessDate);
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
    if (debt.type === 'AR') (await journal(company, debt.scope, `Debt payment ${id}`, `wallet:${row.id}`, 'receivables', amount,body.projectId,body.businessDate));
    else (await journal(company, debt.scope, `Debt payment ${id}`, 'payables', `wallet:${row.id}`, amount,body.projectId,body.businessDate));
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
    (await db.prepare("INSERT INTO cash_shifts(id,company_id,wallet_id,user_id,opening,closing,status,opened_at,closed_at) VALUES(?,?,?,?,?,NULL,'OPEN',?,NULL)").run(id, company.id, row.id, request.user.id, row.balance, now()));
    return { id, walletId: row.id, opening: row.balance, status: 'OPEN' };
  })));
  route('POST', '/shifts/:id/close', async request => (await command(request, 'shifts.write', 'shift.close', async company => {
    const row = (await db.prepare('SELECT * FROM cash_shifts WHERE company_id=? AND id=?').get(company.id, request.params.id));
    if (!row) fail(404, 'shift_not_found');
    if (row.status !== 'OPEN') fail(409, 'shift_closed');
    if (row.user_id !== request.user.id && !(await db.prepare("SELECT 1 FROM memberships WHERE company_id=? AND user_id=? AND role='owner'").get(company.id, request.user.id))) fail(403, 'shift_owner_required');
    const counted = integer(object(request.body).countedAmount, 'countedAmount');
    const expected = (await wallet(company.id, row.wallet_id)).balance;
    (await db.prepare("UPDATE cash_shifts SET status='CLOSED',closing=?,closed_at=?,expected_balance=?,closed_by=? WHERE id=?").run(counted, now(), expected,request.user.id,row.id));
    return { id: row.id, status: 'CLOSED', countedAmount: counted, expectedAmount: expected, difference: counted - expected };
  })));
  route('PUT','/shifts/:id',request=>command(request,'shifts.write','shift.correct',async company=>{
    const old=await db.prepare('SELECT * FROM cash_shifts WHERE company_id=? AND id=?').get(company.id,request.params.id);if(!old)fail(404,'shift_not_found');
    if(old.status!=='CLOSED')fail(409,'shift_not_closed');
    if(old.user_id!==request.user.id&&!await db.prepare("SELECT 1 FROM memberships WHERE company_id=? AND user_id=? AND role='owner'").get(company.id,request.user.id))fail(403,'shift_owner_required');
    const body=object(request.body),counted=integer(body.countedAmount,'countedAmount'),reason=text(body.reason,'reason',500);
    await db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(company.id,'cash_shift',old.id,JSON.stringify({...old,correctionReason:reason}),request.user.id);
    await db.prepare('UPDATE cash_shifts SET closing=? WHERE id=?').run(counted,old.id);
    return {...old,closing:counted,difference:old.expected_balance===null?null:counted-old.expected_balance};
  }));
  route('GET','/shifts/:id/history',async request=>{
    const company=await access(request,'shifts.read');
    if(!await db.prepare('SELECT 1 FROM cash_shifts WHERE company_id=? AND id=?').get(company.id,request.params.id))fail(404,'shift_not_found');
    return {items:await db.prepare("SELECT h.*,u.name AS actor_name FROM entity_history h JOIN users u ON u.id=h.actor_id WHERE h.company_id=? AND h.kind='cash_shift' AND h.entity_id=? ORDER BY h.revision DESC LIMIT 200").all(company.id,request.params.id)};
  });
  route('GET', '/shifts', async request => {
    await access(request,'shifts.read');
    const selected=request.query.walletId;if(selected!==undefined)await wallet(request.params.companyId,selected);
    const status=request.query.status;if(status!==undefined&&!['OPEN','CLOSED'].includes(status))fail(400,'invalid_shift_status');
    const items=await db.prepare(`SELECT s.*,u.name AS opened_by_name,c.name AS closed_by_name,
      CASE WHEN s.expected_balance IS NULL OR s.closing IS NULL THEN NULL ELSE s.closing-s.expected_balance END AS difference
      FROM cash_shifts s JOIN users u ON u.id=s.user_id LEFT JOIN users c ON c.id=s.closed_by
      WHERE s.company_id=? AND s.id>?${selected===undefined?'':' AND s.wallet_id=?'}${status===undefined?'':' AND s.status=?'} ORDER BY s.id LIMIT ?`).all(request.params.companyId,request.query.after??'',...(selected===undefined?[]:[selected]),...(status===undefined?[]:[status]),pageLimit(request.query));
    return {items,nextCursor:items.length===pageLimit(request.query)?items.at(-1).id:null};
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
    if(await commercialSource(company.id,row.id))fail(409,'source_document_edit_required');
    const reason = text(object(request.body).reason, 'reason', 400);
    const result = (await postJournal(db, company, { scope: row.scope, projectId: row.project_id, description: `Reversal: ${reason}`, lines: JSON.parse(row.lines).map(line => ({ account: line.account, debit: line.credit, credit: line.debit })) }));
    await registerManualWalletEntries(db,company.id,result.id,result.lines,'JOURNAL_REVERSAL');
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
    const selected=request.query.projectId;
    if(selected!==undefined&&selected!=='unassigned')await projectReference(db,request.params.companyId,selected);
    const rows=await db.prepare(`SELECT lines FROM journal WHERE company_id=? AND (scope=? OR scope='BOTH') AND business_date>=? AND business_date<=?${selected===undefined?'':' AND project_id IS NOT DISTINCT FROM ?'}`).all(request.params.companyId,ledgerScope,from,to,...(selected===undefined?[]:[selected==='unassigned'?null:selected]));
    let revenue = 0, cogs = 0, expenses = 0;
    for (const row of rows) for (const line of JSON.parse(row.lines)) {
      if (line.account === 'revenue') revenue += line.credit - line.debit;
      if (line.account === 'cogs') cogs += line.debit - line.credit;
      if (['expenses','inventory_loss','depreciation','asset_disposal_loss'].includes(line.account)) expenses += line.debit - line.credit;
    }
    for (const amount of [revenue,cogs,expenses,revenue-cogs-expenses]) if (!Number.isSafeInteger(amount)) fail(422, 'report_amount_overflow');
    return { scope: ledgerScope, from, to, revenue, cogs, grossProfit: revenue-cogs, expenses, netProfit: revenue-cogs-expenses };
  });
  route('GET','/periods',async request=>{
    const company=await access(request,'accounting.read');
    return {items:await db.prepare('SELECT * FROM accounting_periods WHERE company_id=? ORDER BY month DESC').all(company.id)};
  });
  route('GET','/accounting/journal/:id',async request=>{
    const company=await access(request,'accounting.read');
    const row=await db.prepare('SELECT * FROM journal WHERE company_id=? AND id=?').get(company.id,request.params.id);
    if(!row)fail(404,'journal_not_found');
    const order=await orderSource(company.id,row.id),source=await commercialSource(company.id,row.id),asset=await assetSource(company.id,row.id),transfer=await db.prepare("SELECT reference_id FROM wallet_entries WHERE company_id=? AND journal_id=? AND kind IN ('TRANSFER_IN','TRANSFER_OUT') LIMIT 1").get(company.id,row.id);
    const revision=(await db.prepare('SELECT count(*) AS n FROM journal_history WHERE entry_id=?').get(row.id)).n;
    return {...row,revision,lines:JSON.parse(row.lines),sourceDocumentId:source?.document_id??null,sourceOrderId:order?.order_id??null,sourceAssetId:asset?.asset_id??null,sourceTransferId:transfer?.reference_id??null};
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
    const reason=text(body.reason??'Исправление реквизитов или остатка','reason',500);
    // A direct balance edit is an explicit reconciled adjustment, never a silent rewrite of movements.
    await db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(company.id,'wallet',old.id,JSON.stringify({...old,correctionReason:reason}),request.user.id);
    if(balance!==old.balance){
      const delta=balance-old.balance;
      const change=await applyWallet(company.id,old.id,delta,'BALANCE_EDIT',old.id);
      const posting=await journal(company,old.scope,`Balance edit ${old.id}: ${reason}`.slice(0,500),delta>0?`wallet:${old.id}`:'balance_corrections',delta>0?'balance_corrections':`wallet:${old.id}`,Math.abs(delta),null,body.businessDate);
      await db.prepare('UPDATE wallet_entries SET journal_id=? WHERE id=?').run(posting.id,change.entryId);
    }
    await db.prepare('UPDATE wallets SET name=? WHERE id=?').run(name,old.id);
    return {id:old.id,name,balance,scope:old.scope};
  }));
  route('PUT','/accounting/journal/:id',async request=>command(request,'accounting.edit','journal.edit',async company=>{
    const old=await db.prepare('SELECT * FROM journal WHERE company_id=? AND id=?').get(company.id,request.params.id);
    if(!old)fail(404,'journal_not_found');
    const body=object(request.body),reason=body.reason===undefined?'Owner requested edit':text(body.reason,'reason',500);
    if(body.expectedRevision!==undefined&&body.expectedRevision!==(await db.prepare('SELECT count(*) AS n FROM journal_history WHERE entry_id=?').get(old.id)).n)fail(409,'version_conflict');
    await db.prepare("SELECT set_config('app.edit_reason',?,true)").get(reason);
    const replacement={id:old.id,projectId:await projectReference(db,company.id,Object.hasOwn(body,'projectId')?body.projectId:old.project_id),scope:scope(body.scope??old.scope),description:text(body.description??old.description,'description',500),businessDate:businessDate(body.businessDate??old.business_date,company.timezone),lines:normalizeLines({lines:body.lines??JSON.parse(old.lines)})};
    if((await commercialSource(company.id,old.id)||await assetSource(company.id,old.id)||await orderSource(company.id,old.id))&&(replacement.scope!==old.scope||replacement.projectId!==old.project_id||replacement.businessDate!==old.business_date||JSON.stringify(replacement.lines)!==old.lines))fail(409,'source_document_edit_required');
    if([...JSON.parse(old.lines),...replacement.lines].some(line=>line.account.startsWith('wallet:')))await access(request,'wallets.transact');
    await db.prepare('UPDATE journal SET scope=?,description=?,lines=?,business_date=?,project_id=? WHERE id=?').run(replacement.scope,replacement.description,JSON.stringify(replacement.lines),replacement.businessDate,replacement.projectId,old.id);
    await db.prepare('DELETE FROM journal_lines WHERE entry_id=?').run(old.id);
    for(const [position,line]of replacement.lines.entries())await db.prepare('INSERT INTO journal_lines VALUES(?,?,?,?,?)').run(old.id,position,line.account,line.debit,line.credit);
    const linked=await db.prepare('SELECT * FROM wallet_entries WHERE company_id=? AND journal_id=?').all(company.id,old.id);
    for(const entry of linked){
      const amount=replacement.lines.filter(line=>line.account===`wallet:${entry.wallet_id}`).reduce((sum,line)=>sum+line.debit-line.credit,0);
      await db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(company.id,'wallet_entry',entry.id,JSON.stringify(entry),request.user.id);
      await db.prepare('UPDATE wallet_entries SET amount=?,kind=? WHERE id=?').run(amount,['INCOME','EXPENSE','CAPITAL'].includes(entry.kind)?(amount<0?'EXPENSE':replacement.lines.some(line=>line.account==='capital'&&line.credit>0)?'CAPITAL':amount>0?'INCOME':'JOURNAL'):entry.kind,entry.id);
    }
    await syncWalletBalances(db,company.id,[...JSON.parse(old.lines),...replacement.lines]);
    await registerManualWalletEntries(db,company.id,old.id,replacement.lines);
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
    const previous=JSON.parse(old.data),body=object(request.body);
    if(body.expectedRevision!==undefined&&body.expectedRevision!==(await db.prepare("SELECT count(*) AS n FROM entity_history WHERE company_id=? AND kind='order' AND entity_id=?").get(company.id,old.id)).n)fail(409,'version_conflict');
    previous.businessDate??=(await db.prepare('SELECT business_date FROM journal WHERE company_id=? AND description=? ORDER BY created_at LIMIT 1').get(company.id,`Sale ${old.id}`))?.business_date??old.created_at.substring(0,10);
    const next=await orderInput(db,company.id,{...previous,...body},company.timezone,previous);
    if(await db.prepare('SELECT 1 FROM payments p JOIN wallets w ON w.company_id=p.company_id AND w.id=p.wallet_id WHERE p.company_id=? AND p.order_id=? AND NOT p.voided AND w.scope<>? LIMIT 1').get(company.id,old.id,next.scope))fail(400,'incompatible_ledger_scope');
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
      const paid=(await db.prepare('SELECT COALESCE(SUM(amount),0) AS total FROM payments WHERE order_id=? AND NOT voided').get(old.id)).total;
      const newCredit=Math.max(0,paid-next.total);
      const adjust=async(ledgerScope,debit,credit,delta,projectId,date)=>{
        if(delta){const posted=await journal(company,ledgerScope,`Исправление продажи ${old.id}`,delta>0?debit:credit,delta>0?credit:debit,Math.abs(delta),projectId,date??next.businessDate);await db.prepare('INSERT INTO order_postings VALUES(?,?,?,?)').run(company.id,old.id,posted.id,'CORRECTION');}
      };
      if(next.scope===previous.scope && next.projectId===(previous.projectId??null)&&next.businessDate===previous.businessDate){
        await adjust(next.scope,'receivables','revenue',next.net-(previous.net??previous.total),next.projectId);
        await adjust(next.scope,'cogs','inventory',newCost-oldCost,next.projectId);
        await adjust(next.scope,'receivables','vat_payable',next.vat-(previous.vat??0),next.projectId);
      }else{
        await adjust(previous.scope,'receivables','revenue',-(previous.net??previous.total),previous.projectId,previous.businessDate);await adjust(previous.scope,'cogs','inventory',-oldCost,previous.projectId,previous.businessDate);
        await adjust(previous.scope,'receivables','vat_payable',-(previous.vat??0),previous.projectId,previous.businessDate);
        await adjust(next.scope,'receivables','revenue',next.net,next.projectId);await adjust(next.scope,'receivables','vat_payable',next.vat,next.projectId);await adjust(next.scope,'cogs','inventory',newCost,next.projectId);
      }
      await projectOrderPayments(db,company,{id:old.id,data:next});
      next.customerCredit=newCredit;status=paid>=next.total?'CLOSED':'SHIPPED';
    }
    await db.prepare('UPDATE orders SET data=?,status=? WHERE id=?').run(JSON.stringify(next),status,old.id);
    return {id:old.id,status,...next,cogs:shipped?newCost:undefined};
  }));
  route('GET','/orders/:id/history',async request=>{
    await access(request,'orders.read');
    return {items:await db.prepare("SELECT h.*,u.name AS actor_name FROM entity_history h JOIN users u ON u.id=h.actor_id WHERE h.company_id=? AND h.kind='order' AND h.entity_id=? ORDER BY h.revision").all(request.params.companyId,request.params.id),events:await db.prepare('SELECT a.*,u.name AS actor_name FROM audit a JOIN users u ON u.id=a.actor_id WHERE a.company_id=? AND (a.resource_id=? OR a.resource_id IN(SELECT id FROM payments WHERE company_id=? AND order_id=?)) ORDER BY a.sequence DESC LIMIT 200').all(request.params.companyId,request.params.id,request.params.companyId,request.params.id)};
  });
}
