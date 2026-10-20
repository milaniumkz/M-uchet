import { randomUUID } from 'node:crypto';
import { fail, integer, scope, text, businessDate } from './security.js';

export function normalizeLines(input) {
  if (!Array.isArray(input.lines) || input.lines.length < 2 || input.lines.length > 100) fail(400, 'invalid_lines');
  let debits = 0, credits = 0;
  const lines = input.lines.map(line => {
    if(!line||typeof line!=='object'||Array.isArray(line))fail(400,'invalid_line');
    const account = text(line.account, 'account', 64);
    const debit = integer(line.debit ?? 0, 'debit');
    const credit = integer(line.credit ?? 0, 'credit');
    if ((debit === 0) === (credit === 0)) fail(400, 'one_side_required');
    debits += debit; credits += credit;
    return { account, debit, credit };
  });
  if (!Number.isSafeInteger(debits) || debits !== credits) fail(400, 'unbalanced_journal');
  return lines;
}

export async function projectReference(db, companyId, id) {
  if (id === undefined || id === null) return null;
  const row = await db.prepare('SELECT id FROM projects WHERE company_id=? AND id=?').get(companyId, text(id, 'projectId'));
  if (!row) fail(404, 'project_not_found');
  return row.id;
}

// Wallet balances are projections of the ledger, including manual edits.
export async function syncWalletBalances(db,companyId,lines) {
  const ids=[...new Set(lines.filter(line=>line.account.startsWith('wallet:')).map(line=>line.account.slice(7)))];
  for(const id of ids){
    const wallet=await db.prepare('SELECT id FROM wallets WHERE company_id=? AND id=?').get(companyId,id);
    if(!wallet)fail(404,'wallet_not_found');
    const {balance}=await db.prepare(`SELECT COALESCE(SUM(l.debit-l.credit),0) AS balance FROM journal_lines l JOIN journal j ON j.id=l.entry_id WHERE j.company_id=? AND l.account=?`).get(companyId,`wallet:${id}`);
    if(balance<0)fail(409,'insufficient_funds');integer(balance,'wallet_balance');
    await db.prepare('UPDATE wallets SET balance=? WHERE company_id=? AND id=?').run(balance,companyId,id);
  }
}

export async function registerManualWalletEntries(db,companyId,journalId,lines,kind='MANUAL') {
 const totals=new Map();for(const line of lines)if(line.account.startsWith('wallet:')){const id=line.account.slice(7);totals.set(id,(totals.get(id)??0)+line.debit-line.credit);}
 for(const [walletId,amount]of totals){
  const existing=await db.prepare('SELECT id FROM wallet_entries WHERE company_id=? AND wallet_id=? AND journal_id=?').get(companyId,walletId,journalId);
  if(!existing&&amount)await db.prepare('INSERT INTO wallet_entries(id,company_id,wallet_id,amount,kind,reference_id,created_at,journal_id) VALUES(?,?,?,?,?,?,?,?)').run(randomUUID(),companyId,walletId,amount,kind,journalId,new Date().toISOString(),journalId);
 }
}

export async function postJournal(db, company, input) {
  const projectId = await projectReference(db, company.id, input.projectId);
  const ledgerScope = scope(input.scope);
  const lines = normalizeLines(input);
  const id = randomUUID();
  const date = businessDate(input.businessDate ?? company.businessDate, company.timezone);
  (await db.prepare('INSERT INTO journal(id,company_id,scope,currency,description,lines,created_at,business_date,project_id) VALUES(?,?,?,?,?,?,?,?,?)').run(
    id, company.id, ledgerScope, company.currency,
    text(input.description, 'description', 500), JSON.stringify(lines), new Date().toISOString(), date, projectId));
  for (const [position,line] of lines.entries()) await db.prepare('INSERT INTO journal_lines VALUES(?,?,?,?,?)').run(id,position,line.account,line.debit,line.credit);
  await syncWalletBalances(db,company.id,lines);
  return { id, projectId, scope: ledgerScope, currency: company.currency, businessDate: date, lines };
}

export async function allocate(db, companyId, line, ledgerScope) {
  const rows = (await db.prepare(`SELECT * FROM batches WHERE company_id=? AND product_id=?
    AND warehouse_id=? AND scope=? ORDER BY received_sequence`).all(
    companyId, line.productId, line.warehouseId, ledgerScope));
  let remaining = line.quantity;
  const allocations = [];
  for (const batch of rows) {
    const quantity = Math.min(remaining, batch.quantity - batch.reserved);
    if (quantity > 0) allocations.push({ batchId: batch.id, quantity, unitCost: batch.unit_cost });
    remaining -= quantity;
    if (remaining === 0) break;
  }
  if (remaining > 0) fail(409, 'insufficient_inventory');
  return allocations;
}

export async function orderInput(db, companyId, body, timezone='Asia/Almaty', previous) {
  const ledgerScope = scope(body.scope),date=businessDate(body.businessDate,timezone);
  const issuer=await db.prepare('SELECT * FROM company_settings WHERE company_id=?').get(companyId);
  const vatBasisPoints=integer(body.vatBasisPoints??previous?.vatBasisPoints??0,'vatBasisPoints');
  if(![0,1600].includes(vatBasisPoints))fail(422,'unsupported_vat_rate');
  if(vatBasisPoints&&(date<'2026-01-01'||date>'2026-12-31'))fail(422,'vat_rule_version_unavailable');
  if(vatBasisPoints&&!issuer?.vat_registered)fail(422,'vat_registration_required');
  const vatReason=body.vatReason??previous?.vatReason??'';
  if(typeof vatReason!=='string'||vatReason.length>1000)fail(400,'invalid_vat_reason');
  if(!vatBasisPoints&&issuer?.vat_registered&&!vatReason.trim())fail(422,'vat_reason_required');
  let counterpartyId=body.counterpartyId??null,counterparty=null;
  if(counterpartyId){
    counterpartyId=text(counterpartyId,'counterpartyId');
    const party=await db.prepare("SELECT data FROM documents WHERE company_id=? AND kind='clients' AND id=?").get(companyId,text(counterpartyId,'counterpartyId'));
    if(!party)fail(404,'counterparty_not_found');
    counterparty=previous?.counterpartyId===counterpartyId&&body.refreshCounterparty!==true?previous.counterparty:JSON.parse(party.data);
  }
  if (!Array.isArray(body.items) || !body.items.length || body.items.length > 100) fail(400, 'invalid_items');
  const seen = new Set();
  const items = [];
  for (const item of body.items) {
    const productId = text(item.productId, 'productId');
    const warehouseId = text(item.warehouseId, 'warehouseId');
    for (const [kind, id] of [['nomenklatura', productId], ['warehouses', warehouseId]]) {
      if (!(await db.prepare('SELECT 1 FROM documents WHERE company_id=? AND kind=? AND id=?').get(companyId, kind, id))) fail(404, 'catalog_reference_not_found');
    }
    const key = `${productId}:${warehouseId}`;
    if (seen.has(key)) fail(400, 'duplicate_order_line');
    seen.add(key);
    const product=await db.prepare("SELECT data FROM documents WHERE company_id=? AND kind='nomenklatura' AND id=?").get(companyId,productId),warehouse=await db.prepare("SELECT data FROM documents WHERE company_id=? AND kind='warehouses' AND id=?").get(companyId,warehouseId);
    const old=previous?.items.find(l=>l.productId===productId&&l.warehouseId===warehouseId);
    const quantity=integer(item.quantity,'quantity',1),unitPrice=integer(item.unitPrice,'unitPrice'),net=integer(quantity*unitPrice,'line_amount'),vat=Number((BigInt(net)*BigInt(vatBasisPoints)+5000n)/10000n);
    integer(net+vat,'line_total');
    items.push({ productId,warehouseId,quantity,unitPrice,net,vat,total:net+vat,productName:old?.productName&&body.refreshCatalog!==true?old.productName:JSON.parse(product.data).name??'Товар',warehouseName:old?.warehouseName&&body.refreshCatalog!==true?old.warehouseName:JSON.parse(warehouse.data).name??'Склад' });
  }
  const net=items.reduce((sum,item)=>sum+item.net,0),vat=items.reduce((sum,item)=>sum+item.vat,0),total=net+vat;
  integer(total, 'order_total');
  return {number:previous?.number??null,scope:ledgerScope,businessDate:date,projectId:await projectReference(db,companyId,body.projectId),counterpartyId,counterparty,issuer:previous?.issuer??issuer,vatBasisPoints,vatReason:vatReason.trim(),net,vat,total,items,note:body.note===undefined?'':body.note===''?'':text(body.note,'note',2000) };
}
