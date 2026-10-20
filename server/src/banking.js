import { randomUUID } from 'node:crypto';
import { bankRows } from './bank-csv.js';
import { fail, text, hashToken } from './security.js';
import { postJournal, projectReference } from './accounting.js';

export function registerBankRoutes(app, { db, auth, access, command, object, settleDocument }) {
  const base = '/v1/companies/:companyId/bank-imports';
  const route = (method, path, handler) => app.route({ method, url: base + path, bodyLimit:2*1024*1024, preHandler: auth, handler });
  const wallet = async (companyId, id) => {
    const row = await db.prepare('SELECT * FROM wallets WHERE company_id=? AND id=?').get(companyId,text(id,'walletId'));
    if (!row) fail(404,'wallet_not_found'); return row;
  };
  const getRow = async (companyId, importId, rowId) => {
    const row = await db.prepare('SELECT * FROM bank_import_rows WHERE company_id=? AND import_id=? AND id=?').get(companyId,importId,rowId);
    if (!row) fail(404,'bank_row_not_found'); return row;
  };
  const checkDuplicate = async (companyId, walletId, row) => {
    const fingerprint = hashToken(JSON.stringify([row.businessDate,row.amount,row.description,row.counterparty]));
    const old = await db.prepare('SELECT id,import_id,fingerprint FROM bank_import_rows WHERE company_id=? AND wallet_id=? AND external_id=?').get(companyId,walletId,row.externalId);
    if (old && old.fingerprint !== fingerprint) fail(409,'bank_reference_conflict');
    return {fingerprint,old};
  };
  route('POST','/preview',async request=>{
    const company=await access(request,'bank.import'),body=object(request.body);
    await wallet(company.id,body.walletId);
    const rows=bankRows(body),seen=new Map();
    const items=[];
    for(const row of rows){
      const {fingerprint,old}=await checkDuplicate(company.id,body.walletId,row);
      if(seen.has(row.externalId)&&seen.get(row.externalId)!==fingerprint)fail(409,'bank_reference_conflict');
      items.push({...row,duplicate:Boolean(old||seen.has(row.externalId)),existingRowId:old?.id??null});
      seen.set(row.externalId,fingerprint);
    }
    return {items};
  });
  route('POST','',request=>command(request,'bank.import','bank.import',async company=>{
    const body=object(request.body),rows=bankRows(body),bank=await wallet(company.id,body.walletId),id=randomUUID(),createdAt=new Date().toISOString();
    const name=text(body.name??'Банковская выписка','name',200);
    await db.prepare('INSERT INTO bank_imports VALUES(?,?,?,?,?,?)').run(id,company.id,bank.id,name,createdAt,request.user.id);
    let inserted=0,duplicates=0;
    for(const row of rows){
      const {fingerprint,old}=await checkDuplicate(company.id,bank.id,row);
      if(old){duplicates++;continue;}
      await db.prepare('INSERT INTO bank_import_rows(id,company_id,import_id,wallet_id,external_id,business_date,amount,description,counterparty,fingerprint) VALUES(?,?,?,?,?,?,?,?,?,?)')
        .run(randomUUID(),company.id,id,bank.id,row.externalId,row.businessDate,row.amount,row.description,row.counterparty,fingerprint);
      inserted++;
    }
    return {id,name,walletId:bank.id,inserted,duplicates};
  }));
  route('GET','',async request=>{
    const company=await access(request,'bank.read');
    return {items:await db.prepare(`SELECT b.*,w.name AS wallet_name,count(r.id) AS row_count,
      count(r.id) FILTER(WHERE r.journal_id IS NOT NULL) AS posted_count FROM bank_imports b
      JOIN wallets w ON w.id=b.wallet_id LEFT JOIN bank_import_rows r ON r.import_id=b.id
      WHERE b.company_id=? GROUP BY b.id,w.name ORDER BY b.created_at DESC,b.id LIMIT 100`).all(company.id)};
  });
  route('GET','/:id',async request=>{
    const company=await access(request,'bank.read');
    const item=await db.prepare('SELECT * FROM bank_imports WHERE company_id=? AND id=?').get(company.id,request.params.id);
    if(!item)fail(404,'bank_import_not_found');
    const rows=await db.prepare(`SELECT r.*,dp.debt_id AS source_debt_id,COALESCE(NOT dp.active,FALSE) AS debt_payment_inactive,pp.payroll_id AS source_payroll_id,op.order_id AS source_order_id,COALESCE(p.voided,op.voided,pp.voided,NOT dp.active) AS payment_voided,e.id AS wallet_entry_id,e.amount AS current_amount,e.kind AS current_kind,e.reference_id AS current_reference_id,j.description AS current_description,j.business_date AS current_business_date,j.project_id AS current_project_id
      FROM bank_import_rows r LEFT JOIN commercial_payments p ON p.company_id=r.company_id AND p.id=r.payment_id LEFT JOIN wallet_entries e ON e.journal_id=r.journal_id AND e.wallet_id=r.wallet_id
      LEFT JOIN debt_postings dp ON dp.company_id=r.company_id AND dp.journal_id=r.journal_id LEFT JOIN payments op ON op.company_id=r.company_id AND (op.journal_id=r.journal_id OR op.id=e.reference_id) LEFT JOIN payroll_payments pp ON pp.company_id=r.company_id AND (pp.journal_id=r.journal_id OR pp.id=e.reference_id) LEFT JOIN journal j ON j.id=r.journal_id WHERE r.company_id=? AND r.import_id=? ORDER BY r.business_date,r.id`).all(company.id,item.id);
    return {...item,items:rows.map(row=>({...row,reconciliation_status:!row.journal_id?'UNMATCHED':row.payment_voided?'PAYMENT_VOIDED':row.current_amount===null?'SOURCE_MISSING':row.current_amount!==row.amount||row.current_business_date!==row.business_date?'SOURCE_CHANGED':'MATCHED'}))};
  });
  const existingEntry = async (request, companyId, row, id) => {
    await access(request,'wallets.read');
    const entry=await db.prepare(`SELECT e.*,j.business_date FROM wallet_entries e JOIN journal j ON j.company_id=e.company_id AND j.id=e.journal_id
      WHERE e.company_id=? AND e.wallet_id=? AND e.id=?`).get(companyId,row.wallet_id,text(id,'entryId'));
    if(!entry)fail(404,'wallet_entry_not_found');
    if(entry.amount!==row.amount||entry.business_date!==row.business_date)fail(409,'bank_existing_entry_mismatch');
    if(await db.prepare("SELECT 1 FROM debt_postings WHERE company_id=? AND journal_id=? AND kind IN ('PAYMENT','PAYMENT_VOID') AND NOT active").get(companyId,entry.journal_id))fail(409,'bank_payment_voided');
    if(await db.prepare('SELECT 1 FROM payroll_payments WHERE company_id=? AND journal_id=? AND voided=TRUE').get(companyId,entry.journal_id))fail(409,'bank_payment_voided');
    if(await db.prepare('SELECT 1 FROM payments WHERE company_id=? AND journal_id=? AND voided=TRUE').get(companyId,entry.journal_id))fail(409,'bank_payment_voided');
    if(await db.prepare('SELECT 1 FROM commercial_payments WHERE company_id=? AND journal_id=? AND voided=TRUE').get(companyId,entry.journal_id))fail(409,'bank_payment_voided');
    if(await db.prepare('SELECT 1 FROM bank_import_rows WHERE company_id=? AND wallet_id=? AND (journal_id=? OR matched_entry_id=?) AND id<>?').get(companyId,row.wallet_id,entry.journal_id,entry.id,row.id))fail(409,'bank_entry_already_matched');
    return entry;
  };
  route('GET','/:id/rows/:rowId/candidates',async request=>{
    const company=await access(request,'bank.read'); await access(request,'wallets.read');
    const row=await getRow(company.id,request.params.id,request.params.rowId);
    const items=await db.prepare(`SELECT e.id,e.amount,e.kind,e.reference_id,e.journal_id,j.business_date,j.description,j.project_id
      FROM wallet_entries e JOIN journal j ON j.company_id=e.company_id AND j.id=e.journal_id
      WHERE e.company_id=? AND e.wallet_id=? AND e.amount=? AND j.business_date=?
      AND NOT EXISTS(SELECT 1 FROM bank_import_rows r WHERE r.company_id=e.company_id AND r.wallet_id=e.wallet_id AND (r.journal_id=e.journal_id OR r.matched_entry_id=e.id) AND r.id<>?)
      AND NOT EXISTS(SELECT 1 FROM debt_postings p WHERE p.company_id=e.company_id AND p.journal_id=e.journal_id AND p.kind IN ('PAYMENT','PAYMENT_VOID') AND NOT p.active)
      AND NOT EXISTS(SELECT 1 FROM payroll_payments p WHERE p.company_id=e.company_id AND p.journal_id=e.journal_id AND p.voided=TRUE)
      AND NOT EXISTS(SELECT 1 FROM payments p WHERE p.company_id=e.company_id AND p.journal_id=e.journal_id AND p.voided=TRUE)
      AND NOT EXISTS(SELECT 1 FROM commercial_payments p WHERE p.company_id=e.company_id AND p.journal_id=e.journal_id AND p.voided=TRUE)
      ORDER BY e.created_at DESC,e.id LIMIT 100`).all(company.id,row.wallet_id,row.amount,row.business_date,row.id);
    return {items};
  });
  route('PUT','/:id/rows/:rowId',request=>command(request,'bank.review','bank.review',async company=>{
    const row=await getRow(company.id,request.params.id,request.params.rowId),body=object(request.body);
    if(row.journal_id)fail(409,'bank_edit_source_required');
    if(body.version!==row.version)fail(409,'version_conflict');
    const type=body.classification;
    if(!['INCOME','EXPENSE','CAPITAL','DOCUMENT','EXISTING','IGNORE'].includes(type))fail(400,'invalid_bank_classification');
    if((type==='INCOME'||type==='CAPITAL')&&row.amount<0||type==='EXPENSE'&&row.amount>0)fail(400,'bank_direction_mismatch');
    if(type==='EXISTING')await existingEntry(request,company.id,row,body.entryId);
    const projectId=await projectReference(db,company.id,body.projectId),documentId=type==='DOCUMENT'?text(body.documentId,'documentId'):null;
    if(documentId){
      await access(request,'documents.read');
      const doc=await db.prepare('SELECT * FROM commercial_documents WHERE company_id=? AND id=?').get(company.id,documentId);
      if(!doc)fail(404,'document_not_found');
      if((doc.kind==='PURCHASE_ACT')!==(row.amount<0))fail(400,'bank_direction_mismatch');
      if(!['ISSUED','POSTED'].includes(doc.status))fail(409,'document_not_posted');
    }
    await db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(company.id,'bank_row',row.id,JSON.stringify(row),request.user.id);
    await db.prepare('UPDATE bank_import_rows SET classification=?,project_id=?,document_id=?,matched_entry_id=?,version=version+1 WHERE id=?').run(type,projectId,documentId,type==='EXISTING'?body.entryId:null,row.id);
    return getRow(company.id,request.params.id,row.id);
  }));
  route('POST','/:id/rows/:rowId/unmatch',request=>command(request,'bank.review','bank.unmatch',async company=>{
    await access(request,'bank.post');
    const row=await getRow(company.id,request.params.id,request.params.rowId),body=object(request.body);
    if(body.version!==row.version)fail(409,'version_conflict');
    if(row.classification!=='EXISTING'||!row.matched_entry_id||!row.journal_id)fail(409,'bank_unmatch_not_available');
    const reason=text(body.reason,'reason',500);
    await db.prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)').run(company.id,'bank_row',row.id,JSON.stringify({...row,unmatchReason:reason}),request.user.id);
    await db.prepare('UPDATE bank_import_rows SET classification=NULL,project_id=NULL,document_id=NULL,matched_entry_id=NULL,journal_id=NULL,payment_id=NULL,version=version+1 WHERE id=?').run(row.id);
    return getRow(company.id,request.params.id,row.id);
  }));
  route('POST','/:id/rows/:rowId/post',request=>command(request,'bank.post','bank.post',async company=>{
    await access(request,'wallets.transact');
    const row=await getRow(company.id,request.params.id,request.params.rowId),body=object(request.body);
    if(row.journal_id)return row;
    if(body.version!==row.version)fail(409,'version_conflict');
    if(!row.classification||row.classification==='IGNORE')fail(409,'bank_row_not_ready');
    let journalId,paymentId=null,sourceDocumentId=null;
    if(row.classification==='EXISTING'){
      const entry=await existingEntry(request,company.id,row,row.matched_entry_id);
      journalId=entry.journal_id;
      const payment=await db.prepare('SELECT id,document_id FROM commercial_payments WHERE company_id=? AND journal_id=? AND voided=FALSE').get(company.id,journalId);
      paymentId=payment?.id??null;sourceDocumentId=payment?.document_id??null;
    }else if(row.classification==='DOCUMENT'){
      await access(request,'documents.settle');
      // Reuse precisely the same financial command as document payment entry.
      const settled=await settleDocument(company,{...request,params:{...request.params,id:row.document_id},body:{walletId:row.wallet_id,amount:Math.abs(row.amount),businessDate:row.business_date}});
      paymentId=settled.id;
      journalId=(await db.prepare('SELECT journal_id FROM commercial_payments WHERE company_id=? AND id=?').get(company.id,paymentId)).journal_id;
    }else{
      const bank=await wallet(company.id,row.wallet_id),amount=Math.abs(row.amount),cash=`wallet:${bank.id}`;
      const counter=row.classification==='CAPITAL'?'capital':row.amount>0?'revenue':'expenses';
      const entry=await postJournal(db,company,{scope:bank.scope,projectId:row.project_id,businessDate:row.business_date,description:row.description,
        lines:row.amount>0?[{account:cash,debit:amount},{account:counter,credit:amount}]:[{account:counter,debit:amount},{account:cash,credit:amount}]});
      journalId=entry.id;
      await db.prepare('INSERT INTO wallet_entries(id,company_id,wallet_id,amount,kind,reference_id,created_at,journal_id) VALUES(?,?,?,?,?,?,?,?)')
        .run(randomUUID(),company.id,bank.id,row.amount,row.classification,row.id,new Date().toISOString(),entry.id);
    }
    await db.prepare('UPDATE bank_import_rows SET journal_id=?,payment_id=?,document_id=COALESCE(document_id,?),version=version+1 WHERE id=?').run(journalId,paymentId,sourceDocumentId,row.id);
    return getRow(company.id,request.params.id,row.id);
  }));
}
