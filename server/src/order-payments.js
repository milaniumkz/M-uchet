import { postJournal, syncWalletBalances } from './accounting.js';
import { fail,integer } from './security.js';

// Rebuild settlement projections from actual dated payments. Cash identities and
// amounts remain unchanged; prepayments and later excess amounts are advances.
export async function projectOrderPayments(db,company,order){
 const data=order.data;
 for(const old of await db.prepare('SELECT p.id,j.* FROM order_settlement_postings p JOIN journal j ON j.id=p.journal_id WHERE p.company_id=? AND p.order_id=? AND p.active=TRUE').all(company.id,order.id)){
  const reversed=await postJournal(db,company,{scope:old.scope,projectId:old.project_id,businessDate:old.business_date,description:`Пересчёт оплат заказа ${order.id}`,lines:JSON.parse(old.lines).map(l=>({account:l.account,debit:l.credit,credit:l.debit}))});
  await db.prepare('INSERT INTO order_settlement_postings(company_id,order_id,journal_id,active) VALUES(?,?,?,FALSE)').run(company.id,order.id,reversed.id);
 }
 await db.prepare('UPDATE order_settlement_postings SET active=FALSE WHERE company_id=? AND order_id=? AND active=TRUE').run(company.id,order.id);
 const payments=await db.prepare('SELECT p.*,w.scope AS wallet_scope FROM payments p LEFT JOIN wallets w ON w.company_id=p.company_id AND w.id=p.wallet_id WHERE p.company_id=? AND p.order_id=? AND NOT p.voided ORDER BY p.business_date,p.created_at,p.id').all(company.id,order.id);
 let paid=0,advance=0;
 for(const payment of payments){
  if(payment.wallet_id&&payment.wallet_scope!==data.scope)fail(400,'incompatible_ledger_scope');
  if(!payment.journal_id||!payment.business_date)fail(422,'order_payment_source_missing');
  const prepaid=payment.business_date<data.businessDate;
  const againstDebt=prepaid?0:Math.min(payment.amount,Math.max(0,data.total-paid));
  const extra=payment.amount-againstDebt;
  const lines=[{account:payment.wallet_id?`wallet:${payment.wallet_id}`:'cash',debit:payment.amount,credit:0},
    ...(againstDebt?[{account:'receivables',debit:0,credit:againstDebt}]:[]),...(extra?[{account:'customer_advances',debit:0,credit:extra}]:[])];
  const old=await db.prepare('SELECT * FROM journal WHERE company_id=? AND id=?').get(company.id,payment.journal_id);
  if(JSON.stringify(lines)!==old.lines||old.project_id!==data.projectId||old.scope!==data.scope||old.business_date!==payment.business_date){
   await db.prepare("SELECT set_config('app.edit_reason',?,true)").get('Пересчёт оплат товарной продажи');
   await db.prepare('UPDATE journal SET lines=?,project_id=?,scope=?,business_date=? WHERE id=?').run(JSON.stringify(lines),data.projectId,data.scope,payment.business_date,old.id);
   await db.prepare('DELETE FROM journal_lines WHERE entry_id=?').run(old.id);
   for(const [index,line]of lines.entries())await db.prepare('INSERT INTO journal_lines VALUES(?,?,?,?,?)').run(old.id,index,line.account,line.debit,line.credit);
   await syncWalletBalances(db,company.id,lines);
  }
  if(prepaid)advance+=payment.amount;paid+=payment.amount;
 }
 const applied=Math.min(advance,data.total);
 if(applied){
  const posted=await postJournal(db,company,{scope:data.scope,projectId:data.projectId,businessDate:data.businessDate,description:`Зачёт аванса заказа ${order.id}`,lines:[{account:'customer_advances',debit:applied},{account:'receivables',credit:applied}]});
  await db.prepare('INSERT INTO order_settlement_postings(company_id,order_id,journal_id) VALUES(?,?,?)').run(company.id,order.id,posted.id);
 }
 integer(paid,'order_paid');
 return {paid,customerCredit:Math.max(0,paid-data.total),outstanding:Math.max(0,data.total-paid)};
}
