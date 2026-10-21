import { isPurchaseKind, purchaseItems, syncPurchaseStock } from './purchase-stock.js';
import { readSnapshot } from './db.js';
import { planSettlements } from './settlement-planner.js';
import { randomUUID } from 'node:crypto';
import { fail, integer, text, scope, businessDate } from './security.js';
import { postJournal, projectReference, syncWalletBalances } from './accounting.js';

const now = () => new Date().toISOString();
const labels = {
  SALE_INVOICE: 'Счёт на оплату',
  SALE_ACT: 'Акт оказанных услуг',
  PURCHASE_ACT: 'Поступление услуг',
  PURCHASE_GOODS: 'Поступление товаров',
};
const prefixes = { SALE_INVOICE: 'СЧ', SALE_ACT: 'АКТ', PURCHASE_ACT: 'ПУ', PURCHASE_GOODS: 'ПТ' };
const round = (numerator, denominator) => Number((numerator + denominator / 2n) / denominator);
function quantity(value) {
  if (typeof value !== 'string' || !/^\d{1,9}(\.\d{1,3})?$/.test(value))
    fail(400, 'invalid_service_quantity');
  const [whole, fraction = ''] = value.split('.'),
    units = Number(whole) * 1000 + Number(fraction.padEnd(3, '0'));
  integer(units, 'quantity', 1);
  return units;
}
export function serviceTotals(items, rate) {
  if (!Array.isArray(items) || !items.length || items.length > 100) fail(400, 'invalid_items');
  if (![0, 1600].includes(rate)) fail(422, 'unsupported_vat_rate');
  let net = 0,
    vat = 0;
  const lines = items.map((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) fail(400, 'invalid_item');
    const q = quantity(item.quantity),
      price = integer(item.unitPrice, 'unitPrice');
    const amount = round(BigInt(q) * BigInt(price), 1000n);
    integer(amount, 'line_amount');
    const tax = round(BigInt(amount) * BigInt(rate), 10000n);
    integer(tax, 'line_vat');
    net += amount;
    vat += tax;
    return {
      description: text(item.description, 'description', 500),
      unit: text(item.unit ?? 'услуга', 'unit', 40),
      quantity: item.quantity,
      unitPrice: price,
      net: amount,
      vat: tax,
      total: amount + tax,
    };
  });
  integer(net, 'net');
  integer(vat, 'vat');
  integer(net + vat, 'total', 1);
  return { items: lines, net, vat, total: net + vat, rounding: 'HALF_UP_PER_LINE_MINOR' };
}
const escape = (value) =>
  String(value ?? '').replace(
    /[&<>"']/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c],
  );
export function registerCommercialRoutes(app, { db, auth, access, command, pageLimit, object }) {
  const base = '/v1/companies/:companyId/commercial-documents';
  const route = (method, suffix, handler) =>
    app.route({ method, url: base + suffix, preHandler: auth, handler });
  const get = async (companyId, id) => {
    const doc = await db
      .prepare('SELECT * FROM commercial_documents WHERE company_id=? AND id=?')
      .get(companyId, id);
    if (!doc) fail(404, 'document_not_found');
    return doc;
  };
  const dto = async (doc) => {
    const { paid } = await db
      .prepare(
        `SELECT COALESCE(SUM(CASE WHEN kind='REFUND' THEN -amount ELSE amount END),0) AS paid FROM commercial_payments WHERE company_id=? AND voided=FALSE AND (document_id=? OR document_id IN (SELECT id FROM commercial_documents WHERE company_id=? AND source_invoice_id=?))`,
      )
      .get(doc.company_id, doc.source_invoice_id ?? doc.id, doc.company_id, doc.source_invoice_id ?? doc.id);
    const fulfilled = doc.kind === 'SALE_INVOICE' && Boolean(await db.prepare("SELECT 1 FROM commercial_documents WHERE company_id=? AND source_invoice_id=? AND status='POSTED'").get(doc.company_id, doc.id));
    return {
      ...doc,
      paid,
      outstanding: doc.status === 'CANCELLED' || fulfilled ? 0 : Math.max(0, doc.data.total - paid),
      customerCredit: fulfilled ? 0 : Math.max(0, paid - (doc.status === 'CANCELLED' ? 0 : doc.data.total)),
    };
  };
  const input = async (company, body, kind, previous) => {
    if (!Object.hasOwn(labels, kind)) fail(400, 'invalid_document_kind');
    const date = businessDate(body.businessDate ?? previous?.business_date, company.timezone);
    const partyKind = isPurchaseKind(kind) ? 'suppliers' : 'clients';
    const counterpartyId = text(body.counterpartyId, 'counterpartyId');
    const party = await db
      .prepare('SELECT data FROM documents WHERE company_id=? AND kind=? AND id=?')
      .get(company.id, partyKind, counterpartyId);
    const partySnapshot =
      previous?.data.counterpartyId === counterpartyId && body.refreshCounterparty !== true
        ? previous.data.counterparty
        : party
          ? JSON.parse(party.data)
          : null;
    if (!partySnapshot) fail(404, 'counterparty_not_found');
    const issuer =
      (body.refreshIssuer === true ? null : previous?.data.issuer) ??
      (await db.prepare('SELECT * FROM company_settings WHERE company_id=?').get(company.id));
    if (!issuer) fail(422, 'company_settings_required');
    const vatBasisPoints = integer(body.vatBasisPoints ?? 0, 'vatBasisPoints');
    if (vatBasisPoints && (date < '2026-01-01' || date > '2026-12-31'))
      fail(422, 'vat_rule_version_unavailable');
    if (vatBasisPoints && !isPurchaseKind(kind) && !issuer.vat_registered)
      fail(422, 'vat_registration_required');
    if (body.vatReason !== undefined && typeof body.vatReason !== 'string') fail(400, 'invalid_vat_reason');
    const vatReason = body.vatReason === undefined ? '' : body.vatReason.trim();
    if (vatReason.length > 1000) fail(400, 'invalid_vat_reason');
    if (!vatBasisPoints && !isPurchaseKind(kind) && issuer.vat_registered && !vatReason)
      fail(422, 'vat_reason_required');
    const goods = kind === 'PURCHASE_GOODS' ? await purchaseItems(db,company.id,body.items,previous) : null;
    const totals = serviceTotals(goods ?? body.items, vatBasisPoints),
      vatTreatment = body.vatTreatment ?? 'IN_COST';
    if (!['IN_COST', 'PENDING'].includes(vatTreatment)) fail(400, 'invalid_vat_treatment');
    if (vatTreatment === 'PENDING' && (!issuer.vat_registered || !totals.vat || !isPurchaseKind(kind)))
      fail(422, 'invalid_pending_input_vat');
    if(goods)totals.items=totals.items.map((line,i)=>({...goods[i],...line}));
    return {
      businessDate: date,
      scope: scope(body.scope),
      projectId: await projectReference(db, company.id, body.projectId),
      data: {
        counterpartyId,
        counterparty: partySnapshot,
        issuer,
        vatBasisPoints,
        vatReason,
        vatTreatment,
        ...totals,
        note: typeof body.note === 'string' ? body.note.trim().slice(0, 2000) : '',
        externalNumber:
          typeof body.externalNumber === 'string' ? body.externalNumber.trim().slice(0, 150) : '',
        vatRule: vatBasisPoints
          ? {
              id: 'KZ-VAT-STANDARD-2026',
              basisPoints: 1600,
              source: 'https://old.adilet.zan.kz/rus/docs/K2500000214',
              article: '503',
              effectiveFrom: '2026-01-01',
              effectiveTo: '2026-12-31',
            }
          : null,
      },
    };
  };
  const snapshot = async (request, doc) =>
    db
      .prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)')
      .run(doc.company_id, 'commercial_document', doc.id, JSON.stringify(doc), request.user.id);
  const create = async (request, company, body, kind, sourceInvoice = null) => {
    const parsed = await input(company, body, kind),
      year = Number(parsed.businessDate.slice(0, 4)),
      id = randomUUID();
    await db
      .prepare('INSERT INTO document_sequences VALUES(?,?,?,1) ON CONFLICT DO NOTHING')
      .run(company.id, kind, year);
    const sequence = await db
      .prepare(
        'UPDATE document_sequences SET next_number=next_number+1 WHERE company_id=? AND kind=? AND year=? RETURNING next_number-1 AS number',
      )
      .get(company.id, kind, year);
    const number = `${prefixes[kind]}-${year}-${String(sequence.number).padStart(6, '0')}`;
    await db
      .prepare(
        `INSERT INTO commercial_documents(id,company_id,kind,number,status,business_date,project_id,scope,data,source_invoice_id,author_id,created_at,updated_at) VALUES(?,?,?,?,'DRAFT',?,?,?,?,?,?,?,?)`,
      )
      .run(
        id,
        company.id,
        kind,
        number,
        parsed.businessDate,
        parsed.projectId,
        parsed.scope,
        JSON.stringify(parsed.data),
        sourceInvoice,
        request.user.id,
        now(),
        now(),
      );
    return get(company.id, id);
  };
  const relatedPayments = (doc) =>
    db
      .prepare(
        'SELECT * FROM commercial_payments WHERE company_id=? AND voided=FALSE AND (document_id=? OR document_id IN (SELECT id FROM commercial_documents WHERE company_id=? AND source_invoice_id=?)) ORDER BY business_date,id',
      )
      .all(doc.company_id, doc.source_invoice_id ?? doc.id, doc.company_id, doc.source_invoice_id ?? doc.id);
  const recordPosting = async (company, doc, kind, lines, date = doc.business_date) => {
    const entry = await postJournal(db, company, {
      scope: doc.scope,
      projectId: doc.project_id,
      businessDate: date,
      description: `${labels[doc.kind]} ${doc.number}: ${kind}`,
      lines,
    });
    await db
      .prepare('INSERT INTO commercial_postings(company_id,document_id,journal_id,kind) VALUES(?,?,?,?)')
      .run(company.id, doc.id, entry.id, kind);
    return entry;
  };
  const replacePayment = async (company, payment, doc, debtAmount = 0) => {
    const sale = (!isPurchaseKind(doc.kind)) !== (payment.kind === 'REFUND');
    const cash = `wallet:${payment.wallet_id}`;
    const advanceAmount = payment.amount - debtAmount;
    const lines = [
      { account: cash, debit: sale ? payment.amount : 0, credit: sale ? 0 : payment.amount },
      { account: !isPurchaseKind(doc.kind) ? 'receivables' : 'payables', debit: sale ? 0 : debtAmount, credit: sale ? debtAmount : 0 },
      { account: !isPurchaseKind(doc.kind) ? 'customer_advances' : 'supplier_advances', debit: sale ? 0 : advanceAmount, credit: sale ? advanceAmount : 0 },
    ].filter(line => line.debit + line.credit > 0);
    const old = await db.prepare('SELECT * FROM journal WHERE id=?').get(payment.journal_id);
    if (
      JSON.stringify(lines) !== old.lines ||
      old.project_id !== doc.project_id ||
      old.scope !== doc.scope ||
      old.business_date !== payment.business_date
    ) {
      await db.prepare("SELECT set_config('app.edit_reason',?,true)").get('Document/payment correction');
      await db
        .prepare('UPDATE journal SET lines=?,scope=?,project_id=?,business_date=? WHERE id=?')
        .run(JSON.stringify(lines), doc.scope, doc.project_id, payment.business_date, old.id);
      await db.prepare('DELETE FROM journal_lines WHERE entry_id=?').run(old.id);
      for (const [n, line] of lines.entries())
        await db
          .prepare('INSERT INTO journal_lines VALUES(?,?,?,?,?)')
          .run(old.id, n, line.account, line.debit, line.credit);
      await syncWalletBalances(db, company.id, [...JSON.parse(old.lines), ...lines]);
    }
  };
  // Recompute document recognition; actual cash payments retain their identities.
  const projectDocument = async (company, doc, request) => {
    await syncPurchaseStock(db, company, doc, () => access(request, 'inventory.receive'));
    for (const posting of await db
      .prepare(
        'SELECT p.id,j.* FROM commercial_postings p JOIN journal j ON j.id=p.journal_id WHERE p.company_id=? AND p.document_id=? AND p.active=TRUE',
      )
      .all(company.id, doc.id)) {
      const reversal = await postJournal(db, company, {
        scope: posting.scope,
        projectId: posting.project_id,
        businessDate: posting.business_date,
        description: `Исправление ${doc.number}`,
        lines: JSON.parse(posting.lines).map((l) => ({
          account: l.account,
          debit: l.credit,
          credit: l.debit,
        })),
      });
      await db
        .prepare(
          'INSERT INTO commercial_postings(company_id,document_id,journal_id,kind,active) VALUES(?,?,?,?,FALSE)',
        )
        .run(company.id, doc.id, reversal.id, 'Сторно');
    }
    await db
      .prepare(
        'UPDATE commercial_postings SET active=FALSE WHERE company_id=? AND document_id=? AND active=TRUE',
      )
      .run(company.id, doc.id);
    const sale = !isPurchaseKind(doc.kind),
      recognized = doc.kind !== 'SALE_INVOICE' && doc.status === 'POSTED';
    if (recognized) {
      const lines = sale
        ? [
            { account: 'receivables', debit: doc.data.total },
            { account: 'revenue', credit: doc.data.net },
          ]
        : [
            {
              account: doc.kind === 'PURCHASE_GOODS' ? 'inventory' : 'expenses',
              debit: doc.data.vatTreatment === 'PENDING' ? doc.data.net : doc.data.total,
            },
            { account: 'payables', credit: doc.data.total },
          ];
      if (sale && doc.data.vat) lines.push({ account: 'vat_payable', credit: doc.data.vat });
      if (!sale && doc.data.vatTreatment === 'PENDING')
        lines.push({ account: 'pending_input_vat', debit: doc.data.vat });
      await recordPosting(
        company,
        doc,
        'Признание',
        lines.filter((l) => (l.debit ?? 0) + (l.credit ?? 0) > 0),
      );
    }
    const plan = planSettlements({
      recognized, total: doc.data.total, recognitionDate: doc.business_date,
      payments: await relatedPayments(doc),
    });
    for (const { payment, debtAmount } of plan.allocations) {
      let basis = doc;
      if (doc.status !== 'POSTED' && payment.document_id !== doc.id)
        basis = await get(company.id, payment.document_id);
      await replacePayment(company, payment, basis, debtAmount);
    }
    const allocation = plan.applied;
    if (allocation)
      await recordPosting(
        company,
        doc,
        'Зачёт аванса',
        sale
          ? [
              { account: 'customer_advances', debit: allocation },
              { account: 'receivables', credit: allocation },
            ]
          : [
              { account: 'payables', debit: allocation },
              { account: 'supplier_advances', credit: allocation },
            ],
      );
  };
  const projectionBasis = async (doc) =>
    doc.kind === 'SALE_INVOICE'
      ? ((await db
          .prepare(
            "SELECT * FROM commercial_documents WHERE company_id=? AND source_invoice_id=?",
          )
          .get(doc.company_id, doc.id)) ?? doc)
      : doc;
  route('POST', '/preview', async (request) => {
    const company = await access(request, 'documents.write'),
      body = object(request.body);
    const previous = body.documentId ? await get(company.id, text(body.documentId, 'documentId')) : undefined;
    if (previous && previous.kind !== body.kind) fail(400, 'invalid_document_kind');
    return input(company, body, body.kind, previous);
  });
  route('GET', '', (request) => readSnapshot(db, async () => {
    const company=await access(request, 'documents.read');
    const selected = request.query.projectId,
      kind = request.query.kind,
      direction = request.query.direction;
    if (direction !== undefined && !['sales', 'purchases'].includes(direction))
      fail(400, 'invalid_direction');
    const from = businessDate(request.query.from ?? '0001-01-01'),
      to = businessDate(request.query.to ?? '9999-12-31');
    if (from > to) fail(400, 'invalid_date_range');
    const search = typeof request.query.q === 'string' ? request.query.q.trim() : '';
    if (search.length > 200) fail(400, 'invalid_search');
    const pattern = '%' + search.replace(/[\\%_]/g, (c) => '\\' + c) + '%';
    if (kind !== undefined && !Object.hasOwn(labels, kind)) fail(400, 'invalid_document_kind');
    if (selected !== undefined && selected !== 'unassigned')
      await projectReference(db, request.params.companyId, selected);
    const reportScope=request.query.scope;
    if(reportScope!==undefined&&!['ACCOUNTING','MANAGEMENT'].includes(reportScope))fail(400,'invalid_report_scope');
    const status=request.query.status;
    if(status!==undefined&&!['DRAFT','ISSUED','POSTED','CANCELLED'].includes(status))fail(400,'invalid_document_status');
    const counterparty=request.query.counterpartyId;
    if(counterparty!==undefined)text(counterparty,'counterpartyId');
    const filters = `company_id=? AND business_date>=? AND business_date<=?${direction === undefined ? '' : direction === 'sales' ? " AND kind IN ('SALE_INVOICE','SALE_ACT')" : " AND kind IN ('PURCHASE_ACT','PURCHASE_GOODS')"}${search ? " AND (number ILIKE ? OR data->'counterparty'->>'name' ILIKE ?)" : ''}${selected === undefined ? '' : ' AND project_id IS NOT DISTINCT FROM ?'}${kind === undefined ? '' : ' AND kind=?'}${counterparty===undefined?'':" AND data->>'counterpartyId'=?"}${reportScope===undefined?'':" AND scope IN (?,'BOTH')"}${status===undefined?'':' AND status=?'}`;
    const params = [request.params.companyId, from, to,
      ...(search ? [pattern, pattern] : []),
      ...(selected === undefined ? [] : [selected === 'unassigned' ? null : selected]),
      ...(kind === undefined ? [] : [kind]),...(counterparty===undefined?[]:[counterparty]),...(reportScope===undefined?[]:[reportScope]),...(status===undefined?[]:[status])];
    const rows = await db.prepare(`SELECT * FROM commercial_documents WHERE ${filters} AND id>? ORDER BY id LIMIT ?`)
      .all(...params, request.query.after ?? '', pageLimit(request.query));
    // Summaries cover the full filter, independent of pagination. An issued
    // invoice with a posted act must not duplicate the same receivable.
    const summary = await db.prepare(`WITH filtered AS (SELECT * FROM commercial_documents WHERE ${filters})
      SELECT count(*) AS count, count(*) FILTER (WHERE d.status='DRAFT') AS drafts,
      COALESCE(sum(CASE WHEN d.status IN ('ISSUED','POSTED') AND NOT
        (d.kind='SALE_INVOICE' AND EXISTS (SELECT 1 FROM commercial_documents child
          WHERE child.company_id=d.company_id AND child.source_invoice_id=d.id AND child.status='POSTED'))
        THEN greatest(0,(d.data->>'total')::numeric - COALESCE((SELECT sum(CASE WHEN p.kind='REFUND' THEN -p.amount ELSE p.amount END) FROM commercial_payments p
          WHERE p.company_id=d.company_id AND NOT p.voided AND
            (p.document_id=COALESCE(d.source_invoice_id,d.id) OR p.document_id IN (SELECT child.id FROM commercial_documents child WHERE child.company_id=d.company_id AND child.source_invoice_id=COALESCE(d.source_invoice_id,d.id)))),0)) ELSE 0 END),0) AS outstanding
      FROM filtered d`).get(...params);
    return {
      businessDate:businessDate(undefined,company.timezone),
      summary,
      items: await Promise.all(rows.map(dto)),
      nextCursor: rows.length === pageLimit(request.query) ? rows.at(-1).id : null,
    };
  }));
  app.get('/v1/companies/:companyId/counterparties/:kind/:id/service-statement',{preHandler:auth},request=>readSnapshot(db,async()=>{
    const company=await access(request,'catalog.read');await access(request,'documents.read');await access(request,'accounting.read');
    const kind=request.params.kind;if(!['clients','suppliers'].includes(kind))fail(400,'invalid_counterparty_kind');
    const party=await db.prepare('SELECT * FROM documents WHERE company_id=? AND kind=? AND id=?').get(company.id,kind,request.params.id);
    if(!party)fail(404,'counterparty_not_found');
    const from=businessDate(request.query.from??'0001-01-01'),to=businessDate(request.query.to??'9999-12-31');
    if(from>to)fail(400,'invalid_date_range');
    const ledgerScope=request.query.scope??'ACCOUNTING';scope(ledgerScope);if(ledgerScope==='BOTH')fail(400,'invalid_report_scope');
    const selected=request.query.projectId;
    if(selected!==undefined&&selected!=='unassigned')await projectReference(db,company.id,selected);
    let cursorDate='0001-01-01',cursorId='';
    if(request.query.after!==undefined){
      try{const cursor=JSON.parse(Buffer.from(text(request.query.after,'after',300),'base64url').toString());cursorDate=businessDate(cursor.date);cursorId=text(cursor.id,'after',100);}
      catch{fail(400,'invalid_cursor');}
    }
    const cte=`WITH docs AS(SELECT * FROM commercial_documents WHERE company_id=? AND data->>'counterpartyId'=? AND ${kind==='clients'?"kind IN ('SALE_INVOICE','SALE_ACT')":"kind='PURCHASE_ACT'"}),
      sources AS(SELECT p.journal_id,d.id AS document_id FROM commercial_postings p JOIN docs d ON d.id=p.document_id AND d.company_id=p.company_id
        UNION SELECT p.journal_id,d.id FROM commercial_payments p JOIN commercial_documents original ON original.id=p.document_id AND original.company_id=p.company_id LEFT JOIN commercial_documents child ON child.source_invoice_id=original.id AND child.company_id=original.company_id AND child.status='POSTED' JOIN docs d ON d.id=COALESCE(child.id,original.id)
        UNION SELECT e.journal_id,d.id FROM commercial_payments p JOIN commercial_documents original ON original.id=p.document_id AND original.company_id=p.company_id LEFT JOIN commercial_documents child ON child.source_invoice_id=original.id AND child.company_id=original.company_id AND child.status='POSTED' JOIN docs d ON d.id=COALESCE(child.id,original.id) JOIN wallet_entries e ON e.company_id=p.company_id AND e.reference_id=p.id WHERE e.journal_id IS NOT NULL),
      filtered AS(SELECT DISTINCT j.* FROM journal j JOIN sources s ON s.journal_id=j.id WHERE j.company_id=? AND j.scope IN (?,'BOTH')${selected===undefined?'':' AND j.project_id IS NOT DISTINCT FROM ?'})`;
    const params=[company.id,party.id,company.id,ledgerScope,...(selected===undefined?[]:[selected==='unassigned'?null:selected])];
    const accounts=kind==='clients'?['receivables','customer_advances']:['payables','supplier_advances'];
    const balances=await db.prepare(`${cte} SELECT l.account,
      COALESCE(sum(l.debit-l.credit) FILTER(WHERE j.business_date<?),0) AS opening,
      COALESCE(sum(l.debit) FILTER(WHERE j.business_date>=?),0) AS debit,
      COALESCE(sum(l.credit) FILTER(WHERE j.business_date>=?),0) AS credit,
      COALESCE(sum(l.debit-l.credit),0) AS closing
      FROM filtered j JOIN journal_lines l ON l.entry_id=j.id WHERE j.business_date<=? AND l.account IN (?,?) GROUP BY l.account`).all(...params,from,from,from,to,...accounts);
    const limit=pageLimit(request.query);
    const rows=await db.prepare(`${cte} SELECT j.id,j.business_date,j.description,j.project_id,
      (SELECT min(s.document_id) FROM sources s WHERE s.journal_id=j.id) AS document_id,
      COALESCE((SELECT jsonb_agg(jsonb_build_object('account',l.account,'debit',l.debit,'credit',l.credit) ORDER BY l.position) FROM journal_lines l WHERE l.entry_id=j.id AND l.account IN (?,?)),'[]'::jsonb) AS lines
      FROM filtered j WHERE j.business_date>=? AND j.business_date<=? AND (j.business_date,j.id)>(?::date,?)
      AND EXISTS(SELECT 1 FROM journal_lines l WHERE l.entry_id=j.id AND l.account IN (?,?)) ORDER BY j.business_date,j.id LIMIT ?`).all(...params,...accounts,from,to,cursorDate,cursorId,...accounts,limit);
    return {counterparty:{...party,data:JSON.parse(party.data)},scope:ledgerScope,from,to,accounts:accounts.map(account=>balances.find(b=>b.account===account)??{account,opening:0,debit:0,credit:0,closing:0}),items:rows,
      nextCursor:rows.length===limit?Buffer.from(JSON.stringify({date:rows.at(-1).business_date,id:rows.at(-1).id})).toString('base64url'):null};
  }));
  route('GET', '/:id', async (request) => {
    await access(request, 'documents.read');
    return dto(await get(request.params.companyId, request.params.id));
  });
  route('POST', '', (request) =>
    command(request, 'documents.write', 'document.create', async (company) =>
      dto(await create(request, company, object(request.body), request.body.kind)),
    ),
  );
  route('PUT', '/:id', (request) =>
    command(request, 'documents.write', 'document.edit', async (company) => {
      const old = await get(company.id, request.params.id),
        body = object(request.body);
      if (body.version !== old.version) fail(409, 'version_conflict');
      if (old.status === 'POSTED' || (await relatedPayments(old)).length)
        await access(request, 'documents.post');
      const parsed = await input(
        company,
        {
          ...old.data,
          businessDate: old.business_date,
          scope: old.scope,
          projectId: old.project_id,
          ...body,
        },
        old.kind,
        old,
      );
      await snapshot(request, old);
      await db
        .prepare(
          'UPDATE commercial_documents SET data=?,business_date=?,scope=?,project_id=?,version=version+1,updated_at=? WHERE id=?',
        )
        .run(JSON.stringify(parsed.data), parsed.businessDate, parsed.scope, parsed.projectId, now(), old.id);
      const doc = await get(company.id, old.id);
      await projectDocument(company, await projectionBasis(doc), request);
      return dto(doc);
    }),
  );
  route('POST', '/:id/post', (request) =>
    command(request, 'documents.post', 'document.post', async (company) => {
      const old = await get(company.id, request.params.id);
      if (old.status === 'POSTED' || old.status === 'ISSUED') return dto(old);
      if (!old.data.issuer.identifier) fail(422, 'issuer_identifier_required');
      if (!old.data.counterparty.name) fail(422, 'counterparty_name_required');
      await snapshot(request, old);
      await db
        .prepare('UPDATE commercial_documents SET status=?,version=version+1,updated_at=? WHERE id=?')
        .run(old.kind === 'SALE_INVOICE' ? 'ISSUED' : 'POSTED', now(), old.id);
      const doc = await get(company.id, old.id);
      await projectDocument(company, await projectionBasis(doc), request);
      return dto(doc);
    }),
  );
  route('POST', '/:id/cancel', (request) =>
    command(request, 'documents.post', 'document.cancel', async (company) => {
      const old = await get(company.id, request.params.id);
      if (old.status === 'CANCELLED') return dto(old);
      await snapshot(request, old);
      await db
        .prepare(
          "UPDATE commercial_documents SET status='CANCELLED',version=version+1,updated_at=? WHERE id=?",
        )
        .run(now(), old.id);
      const doc = await get(company.id, old.id);
      await projectDocument(company, await projectionBasis(doc), request);
      return dto(doc);
    }),
  );
  route('POST', '/:id/act', (request) =>
    command(request, 'documents.write', 'document.act', async (company) => {
      const invoice = await get(company.id, request.params.id);
      if (invoice.kind !== 'SALE_INVOICE' || invoice.status !== 'ISSUED') fail(409, 'invoice_not_issued');
      const existing = await db
        .prepare('SELECT * FROM commercial_documents WHERE company_id=? AND source_invoice_id=?')
        .get(company.id, invoice.id);
      if (existing) return dto(existing);
      return dto(
        await create(
          request,
          company,
          {
            ...invoice.data,
            businessDate: invoice.business_date,
            projectId: invoice.project_id,
            scope: invoice.scope,
          },
          'SALE_ACT',
          invoice.id,
        ),
      );
    }),
  );
  const settleDocument = async (company, request) => {
      await access(request, 'wallets.transact');
      const doc = await get(company.id, request.params.id);
      const body = object(request.body),
        kind = body.kind ?? 'PAYMENT';
      if (!['PAYMENT', 'REFUND'].includes(kind)) fail(400, 'invalid_payment_kind');
      if (kind === 'PAYMENT' && !['ISSUED', 'POSTED'].includes(doc.status) && !(doc.kind === 'PURCHASE_GOODS' && doc.status === 'DRAFT')) fail(409, 'document_not_posted');
      const
        amount = integer(body.amount, 'amount', 1),
        walletId = text(body.walletId, 'walletId'),
        id = randomUUID(),
        date = businessDate(body.businessDate ?? company.businessDate, company.timezone);
      const wallet = await db
        .prepare('SELECT * FROM wallets WHERE company_id=? AND id=?')
        .get(company.id, walletId);
      if (!wallet) fail(404, 'wallet_not_found');
      const basis = await projectionBasis(doc);
      const current = await dto(basis.status === 'POSTED' ? basis : doc);
      if (kind === 'PAYMENT' && amount > current.outstanding) fail(409, 'overpayment');
      planSettlements({recognized:basis.kind !== 'SALE_INVOICE' && basis.status === 'POSTED', total:basis.data.total,
        recognitionDate:basis.business_date, payments:[...await relatedPayments(basis), {id,amount,business_date:date,kind}]});
      const sale = (!isPurchaseKind(basis.kind)) !== (kind === 'REFUND'),
        advance = basis.kind === 'SALE_INVOICE' || basis.status !== 'POSTED' || date < basis.business_date;
      const account = !isPurchaseKind(basis.kind)
          ? advance
            ? 'customer_advances'
            : 'receivables'
          : advance
            ? 'supplier_advances'
            : 'payables',
        cash = `wallet:${wallet.id}`;
      const entry = await postJournal(db, company, {
        scope: basis.scope,
        projectId: basis.project_id,
        businessDate: date,
        description: `${kind === 'REFUND' ? 'Возврат денег' : 'Оплата'} ${doc.number}`,
        lines: sale
          ? [
              { account: cash, debit: amount },
              { account, credit: amount },
            ]
          : [
              { account, debit: amount },
              { account: cash, credit: amount },
            ],
      });
      await db
        .prepare(
          'INSERT INTO commercial_payments(id,company_id,document_id,wallet_id,amount,business_date,journal_id,created_at,kind) VALUES(?,?,?,?,?,?,?,?,?)',
        )
        .run(id, company.id, doc.id, walletId, amount, date, entry.id, now(), kind);
      await db
        .prepare(
          'INSERT INTO wallet_entries(id,company_id,wallet_id,amount,kind,reference_id,created_at,journal_id) VALUES(?,?,?,?,?,?,?,?)',
        )
        .run(
          randomUUID(),
          company.id,
          walletId,
          sale ? amount : -amount,
          kind === 'REFUND' ? 'DOCUMENT_REFUND' : 'DOCUMENT_PAYMENT',
          id,
          now(),
          entry.id,
        );
      await projectDocument(company, basis, request);
      return { id, document: await dto(await get(company.id, doc.id)) };
  };
  route('POST', '/:id/payments', request => command(request, 'documents.settle', 'document.payment', company => settleDocument(company, request)));
  route('PUT', '/:id/payments/:paymentId', (request) =>
    command(request, 'documents.settle', 'document.payment.edit', async (company) => {
      await access(request, 'wallets.transact');
      const doc = await get(company.id, request.params.id),
        body = object(request.body);
      const old = await db
        .prepare('SELECT * FROM commercial_payments WHERE company_id=? AND document_id=? AND id=?')
        .get(company.id, doc.id, request.params.paymentId);
      if (!old) fail(404, 'payment_not_found');
      if (body.version !== undefined && body.version !== old.version) fail(409, 'version_conflict');
      if (body.kind !== undefined && body.kind !== old.kind) fail(400, 'payment_kind_immutable');
      if (old.voided) fail(409, 'payment_voided');
      const amount = integer(body.amount ?? old.amount, 'amount', 1),
        walletId = text(body.walletId ?? old.wallet_id, 'walletId'),
        date = businessDate(body.businessDate ?? old.business_date, company.timezone);
      if (!(await db.prepare('SELECT 1 FROM wallets WHERE company_id=? AND id=?').get(company.id, walletId)))
        fail(404, 'wallet_not_found');
      await db
        .prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)')
        .run(company.id, 'commercial_payment', old.id, JSON.stringify(old), request.user.id);
      await db
        .prepare('UPDATE commercial_payments SET amount=?,wallet_id=?,business_date=?,version=version+1 WHERE id=?')
        .run(amount, walletId, date, old.id);
      await projectDocument(company, await projectionBasis(doc), request);
      await db
        .prepare('UPDATE wallet_entries SET wallet_id=?,amount=? WHERE company_id=? AND journal_id=?')
        .run(walletId, (isPurchaseKind(doc.kind)) !== (old.kind === 'REFUND') ? -amount : amount, company.id, old.journal_id);
      return { id: old.id, document: await dto(doc) };
    }),
  );
  for (const [action, voided] of [
    ['void', true],
    ['restore', false],
  ])
    route('POST', `/:id/payments/:paymentId/${action}`, (request) =>
      command(request, 'documents.settle', `document.payment.${action}`, async (company) => {
        await access(request, 'wallets.transact');
        const doc = await get(company.id, request.params.id);
        const old = await db
          .prepare('SELECT * FROM commercial_payments WHERE company_id=? AND document_id=? AND id=?')
          .get(company.id, doc.id, request.params.paymentId);
        if (!old) fail(404, 'payment_not_found');
        const body = object(request.body);
        if (body.version !== undefined && body.version !== old.version) fail(409, 'version_conflict');
        if (old.voided === voided) return { id: old.id, document: await dto(doc) };
        const basis = await projectionBasis(doc), payments = await relatedPayments(basis);
        planSettlements({recognized:basis.kind !== 'SALE_INVOICE' && basis.status === 'POSTED',total:basis.data.total,
          recognitionDate:basis.business_date, payments:voided ? payments.filter(p=>p.id!==old.id) : [...payments,old]});
        const source = await db
          .prepare('SELECT * FROM journal WHERE company_id=? AND id=?')
          .get(company.id, voided ? old.journal_id : old.void_journal_id);
        await db
          .prepare(
            'INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)',
          )
          .run(company.id, 'commercial_payment', old.id, JSON.stringify(old), request.user.id);
        const entry = await postJournal(db, company, {
          scope: source.scope,
          projectId: source.project_id,
          businessDate: source.business_date,
          description: `${voided ? 'Отмена' : 'Восстановление'} записи оплаты ${doc.number}`,
          lines: JSON.parse(source.lines).map((l) => ({
            account: l.account,
            debit: l.credit,
            credit: l.debit,
          })),
        });
        await db
          .prepare('UPDATE commercial_payments SET voided=?,void_journal_id=?,version=version+1 WHERE id=?')
          .run(voided, voided ? entry.id : null, old.id);
        const walletLine = entry.lines.find((l) => l.account === `wallet:${old.wallet_id}`);
        await db
          .prepare(
            'INSERT INTO wallet_entries(id,company_id,wallet_id,amount,kind,reference_id,created_at,journal_id) VALUES(?,?,?,?,?,?,?,?)',
          )
          .run(
            randomUUID(),
            company.id,
            old.wallet_id,
            walletLine.debit - walletLine.credit,
            voided ? 'PAYMENT_VOID' : 'PAYMENT_RESTORE',
            old.id,
            now(),
            entry.id,
          );
        await projectDocument(company, await projectionBasis(doc), request);
        return { id: old.id, document: await dto(doc) };
      }),
    );
  route('GET', '/:id/payments', async (request) => {
    await access(request, 'documents.read');
    const doc = await get(request.params.companyId, request.params.id);
    return {
      items: await db
        .prepare(
          'SELECT * FROM commercial_payments WHERE company_id=? AND (document_id=? OR document_id IN (SELECT id FROM commercial_documents WHERE company_id=? AND source_invoice_id=?)) ORDER BY business_date,id',
        )
        .all(doc.company_id, doc.source_invoice_id ?? doc.id, doc.company_id, doc.source_invoice_id ?? doc.id),
    };
  });
  route('GET', '/:id/payments/:paymentId/history', async request => {
    await access(request, 'documents.read');
    const doc = await get(request.params.companyId, request.params.id);
    const payment = await db.prepare('SELECT * FROM commercial_payments WHERE company_id=? AND document_id=? AND id=?')
      .get(doc.company_id,doc.id,request.params.paymentId);
    if(!payment)fail(404,'payment_not_found');
    return {payment,items:await db.prepare("SELECT h.*,u.name AS actor_name FROM entity_history h JOIN users u ON u.id=h.actor_id WHERE h.company_id=? AND h.kind='commercial_payment' AND h.entity_id=? ORDER BY revision DESC LIMIT 200").all(doc.company_id,payment.id)};
  });
  route('GET', '/:id/history', async (request) => {
    await access(request, 'documents.read');
    await get(request.params.companyId, request.params.id);
    return {
      items: await db
        .prepare(
          "SELECT h.*,u.name AS actor_name FROM entity_history h JOIN users u ON u.id=h.actor_id WHERE h.company_id=? AND h.kind='commercial_document' AND h.entity_id=? ORDER BY revision",
        )
        .all(request.params.companyId, request.params.id),
    };
  });
  route('GET', '/:id/movements', async (request) => {
    await access(request, 'accounting.read');
    const doc = await get(request.params.companyId, request.params.id);
    const rows = await db
      .prepare(
        'SELECT j.*,p.kind AS movement_kind,p.active FROM commercial_postings p JOIN journal j ON j.id=p.journal_id WHERE p.company_id=? AND p.document_id=? ORDER BY p.id',
      )
      .all(doc.company_id, doc.id);
    return { items: rows.map((r) => ({ ...r, lines: JSON.parse(r.lines) })) };
  });
  route('GET', '/:id/stock', request => readSnapshot(db, async () => {
    const company = await access(request,'documents.read');await access(request,'inventory.read');
    const doc=await get(company.id,request.params.id);
    if(doc.kind!=='PURCHASE_GOODS')fail(400,'invalid_document_kind');
    return {items:await db.prepare(`SELECT b.*,s.original_quantity,p.data::jsonb->>'name' AS product_name,w.data::jsonb->>'name' AS warehouse_name
      FROM commercial_stock_layers s JOIN batches b ON b.company_id=s.company_id AND b.id=s.batch_id
      LEFT JOIN documents p ON p.company_id=b.company_id AND p.kind='nomenklatura' AND p.id=b.product_id
      LEFT JOIN documents w ON w.company_id=b.company_id AND w.kind='warehouses' AND w.id=b.warehouse_id
      WHERE s.company_id=? AND s.document_id=? ORDER BY b.received_sequence`).all(company.id,doc.id)};
  }));
  route('GET', '/:id/files', async (request) => {
    await access(request, 'documents.read');
    await access(request, 'files.read');
    const doc = await get(request.params.companyId, request.params.id);
    return {
      items: await db
        .prepare(
          'SELECT f.* FROM commercial_attachments a JOIN files f ON f.id=a.file_id AND f.company_id=a.company_id WHERE a.company_id=? AND a.document_id=? ORDER BY a.created_at,f.id',
        )
        .all(doc.company_id, doc.id),
    };
  });
  route('POST', '/:id/files', (request) =>
    command(request, 'documents.write', 'document.attachment', async (company) => {
      await access(request, 'files.read');
      const doc = await get(company.id, request.params.id),
        fileId = text(object(request.body).fileId, 'fileId');
      const file = await db
        .prepare('SELECT * FROM files WHERE company_id=? AND id=?')
        .get(company.id, fileId);
      if (!file) fail(404, 'file_not_found');
      const attachments = await db
        .prepare('SELECT file_id FROM commercial_attachments WHERE company_id=? AND document_id=?')
        .all(company.id, doc.id);
      await db
        .prepare('INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)')
        .run(
          company.id,
          'commercial_document',
          doc.id,
          JSON.stringify({ ...doc, attachments }),
          request.user.id,
        );
      await db
        .prepare('INSERT INTO commercial_attachments VALUES(?,?,?,?) ON CONFLICT DO NOTHING')
        .run(company.id, doc.id, file.id, now());
      return { id: doc.id, file };
    }),
  );
  route('GET', '/:id/export-data', async (request) => {
    await access(request, 'documents.export');
    const doc = await get(request.params.companyId, request.params.id);
    await db
      .prepare('INSERT INTO audit(company_id,actor_id,action,resource_id,created_at) VALUES(?,?,?,?,?)')
      .run(doc.company_id, request.user.id, 'document.export', doc.id, now());
    return dto(doc);
  });
  route('GET', '/:id/print', async (request, reply) => {
    await access(request, 'documents.export');
    const doc = await dto(await get(request.params.companyId, request.params.id)),
      d = doc.data;
    const money = (amount) => (amount / 100).toFixed(2);
    const html = `<!doctype html><html lang="ru"><meta charset="utf-8"><title>${escape(doc.number)}</title><body><h1>${labels[doc.kind]} № ${escape(doc.number)}</h1><p>от ${escape(doc.business_date)} · ${escape(doc.status)}</p><p>${isPurchaseKind(doc.kind) ? 'Покупатель / фирма' : 'Исполнитель / фирма'}: ${escape(d.issuer.legal_name)} · БИН/ИИН ${escape(d.issuer.identifier)}</p><p>${doc.kind === 'PURCHASE_GOODS' ? 'Поставщик' : 'Контрагент'}: ${escape(d.counterparty.name)} · ${escape(d.counterparty.identifier ?? d.counterparty.bin ?? '')}</p><table border="1" cellpadding="8"><thead><tr><th>${doc.kind === 'PURCHASE_GOODS' ? 'Товар / склад' : 'Услуга'}</th><th>Ед.</th><th>Количество</th><th>Цена без НДС</th><th>Без НДС</th><th>НДС</th><th>Итого</th></tr></thead><tbody>${d.items.map((l) => `<tr><td>${escape(l.description)}${l.warehouseName ? '<br>Склад: '+escape(l.warehouseName) : ''}</td><td>${escape(l.unit)}</td><td>${escape(l.quantity)}</td><td>${money(l.unitPrice)}</td><td>${money(l.net)}</td><td>${money(l.vat)}</td><td>${money(l.total)}</td></tr>`).join('')}</tbody></table><p>Без НДС: ${money(d.net)} · НДС: ${money(d.vat)} · Итого: ${money(d.total)}</p><p>${escape(d.vatReason)}</p><p>${escape(d.note)}</p><p>Ответственные лица / подписи: __________________________</p><p>Внутренняя печатная форма. Не является ЭСФ или фискальным чеком. Подписи не проставлены.</p></body></html>`;
    // HTML contains escaped text and no executable content. API-wide CSP remains default-src none.
    reply
      .type('text/html; charset=utf-8')
      .header('Content-Disposition', `inline; filename="document-${doc.id}.html"`);
    return html;
  });
  return { settleDocument };
}
