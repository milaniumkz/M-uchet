import { randomUUID } from 'node:crypto';
import { fail, integer, text, scope, businessDate } from './security.js';
import { postJournal, projectReference, syncWalletBalances } from './accounting.js';

const now = () => new Date().toISOString();
const labels = {
  SALE_INVOICE: 'Счёт на оплату',
  SALE_ACT: 'Акт оказанных услуг',
  PURCHASE_ACT: 'Поступление услуг',
};
const prefixes = { SALE_INVOICE: 'СЧ', SALE_ACT: 'АКТ', PURCHASE_ACT: 'ПУ' };
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
        'SELECT COALESCE(SUM(amount),0) AS paid FROM commercial_payments WHERE company_id=? AND voided=FALSE AND (document_id=? OR document_id=?)',
      )
      .get(doc.company_id, doc.id, doc.source_invoice_id ?? doc.id);
    return {
      ...doc,
      paid,
      outstanding: doc.status === 'CANCELLED' ? 0 : Math.max(0, doc.data.total - paid),
      customerCredit: Math.max(0, paid - (doc.status === 'CANCELLED' ? 0 : doc.data.total)),
    };
  };
  const input = async (company, body, kind, previous) => {
    if (!Object.hasOwn(labels, kind)) fail(400, 'invalid_document_kind');
    const date = businessDate(body.businessDate ?? previous?.business_date, company.timezone);
    const partyKind = kind === 'PURCHASE_ACT' ? 'suppliers' : 'clients';
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
    if (vatBasisPoints && kind !== 'PURCHASE_ACT' && !issuer.vat_registered)
      fail(422, 'vat_registration_required');
    if (body.vatReason !== undefined && typeof body.vatReason !== 'string') fail(400, 'invalid_vat_reason');
    const vatReason = body.vatReason === undefined ? '' : body.vatReason.trim();
    if (vatReason.length > 1000) fail(400, 'invalid_vat_reason');
    if (!vatBasisPoints && kind !== 'PURCHASE_ACT' && issuer.vat_registered && !vatReason)
      fail(422, 'vat_reason_required');
    const totals = serviceTotals(body.items, vatBasisPoints),
      vatTreatment = body.vatTreatment ?? 'IN_COST';
    if (!['IN_COST', 'PENDING'].includes(vatTreatment)) fail(400, 'invalid_vat_treatment');
    if (vatTreatment === 'PENDING' && (!issuer.vat_registered || !totals.vat || kind !== 'PURCHASE_ACT'))
      fail(422, 'invalid_pending_input_vat');
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
        'SELECT * FROM commercial_payments WHERE company_id=? AND voided=FALSE AND (document_id=? OR document_id=?) ORDER BY business_date,id',
      )
      .all(doc.company_id, doc.id, doc.source_invoice_id ?? doc.id);
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
  const replacePayment = async (company, payment, doc) => {
    const sale = doc.kind !== 'PURCHASE_ACT',
      advance =
        doc.kind === 'SALE_INVOICE' || doc.status !== 'POSTED' || payment.business_date < doc.business_date;
    const account = sale
      ? advance
        ? 'customer_advances'
        : 'receivables'
      : advance
        ? 'supplier_advances'
        : 'payables';
    const cash = `wallet:${payment.wallet_id}`,
      lines = sale
        ? [
            { account: cash, debit: payment.amount, credit: 0 },
            { account, debit: 0, credit: payment.amount },
          ]
        : [
            { account, debit: payment.amount, credit: 0 },
            { account: cash, debit: 0, credit: payment.amount },
          ];
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
    return advance;
  };
  // Recompute document recognition; actual cash payments retain their identities.
  const projectDocument = async (company, doc) => {
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
    const sale = doc.kind !== 'PURCHASE_ACT',
      recognized = doc.kind !== 'SALE_INVOICE' && doc.status === 'POSTED';
    if (recognized) {
      const lines = sale
        ? [
            { account: 'receivables', debit: doc.data.total },
            { account: 'revenue', credit: doc.data.net },
          ]
        : [
            {
              account: 'expenses',
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
    let advancePaid = 0,
      regularPaid = 0;
    for (const payment of await relatedPayments(doc)) {
      let basis = doc;
      if (doc.status === 'CANCELLED' && payment.document_id !== doc.id)
        basis = await get(company.id, payment.document_id);
      if (await replacePayment(company, payment, basis)) advancePaid += payment.amount;
      else regularPaid += payment.amount;
    }
    if (recognized) {
      const allocation = Math.min(advancePaid, doc.data.total);
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
      const credit = Math.max(0, regularPaid + allocation - doc.data.total);
      if (credit)
        await recordPosting(
          company,
          doc,
          'Переплата',
          sale
            ? [
                { account: 'receivables', debit: credit },
                { account: 'customer_advances', credit: credit },
              ]
            : [
                { account: 'supplier_advances', debit: credit },
                { account: 'payables', credit: credit },
              ],
        );
    }
  };
  const projectionBasis = async (doc) =>
    doc.kind === 'SALE_INVOICE'
      ? ((await db
          .prepare(
            "SELECT * FROM commercial_documents WHERE company_id=? AND source_invoice_id=? AND status='POSTED'",
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
  route('GET', '', async (request) => {
    await access(request, 'documents.read');
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
    const filters = `company_id=? AND business_date>=? AND business_date<=?${direction === undefined ? '' : direction === 'sales' ? " AND kind IN ('SALE_INVOICE','SALE_ACT')" : " AND kind='PURCHASE_ACT'"}${search ? " AND (number ILIKE ? OR data->'counterparty'->>'name' ILIKE ?)" : ''}${selected === undefined ? '' : ' AND project_id IS NOT DISTINCT FROM ?'}${kind === undefined ? '' : ' AND kind=?'}`;
    const params = [request.params.companyId, from, to,
      ...(search ? [pattern, pattern] : []),
      ...(selected === undefined ? [] : [selected === 'unassigned' ? null : selected]),
      ...(kind === undefined ? [] : [kind])];
    const rows = await db.prepare(`SELECT * FROM commercial_documents WHERE ${filters} AND id>? ORDER BY id LIMIT ?`)
      .all(...params, request.query.after ?? '', pageLimit(request.query));
    // Summaries cover the full filter, independent of pagination. An issued
    // invoice with a posted act must not duplicate the same receivable.
    const summary = await db.prepare(`WITH filtered AS (SELECT * FROM commercial_documents WHERE ${filters})
      SELECT count(*) AS count, count(*) FILTER (WHERE d.status='DRAFT') AS drafts,
      COALESCE(sum(CASE WHEN d.status IN ('ISSUED','POSTED') AND NOT
        (d.kind='SALE_INVOICE' AND EXISTS (SELECT 1 FROM commercial_documents child
          WHERE child.company_id=d.company_id AND child.source_invoice_id=d.id AND child.status='POSTED'))
        THEN greatest(0,(d.data->>'total')::numeric - COALESCE((SELECT sum(p.amount) FROM commercial_payments p
          WHERE p.company_id=d.company_id AND NOT p.voided AND
            (p.document_id=d.id OR p.document_id=d.source_invoice_id)),0)) ELSE 0 END),0) AS outstanding
      FROM filtered d`).get(...params);
    return {
      summary,
      items: await Promise.all(rows.map(dto)),
      nextCursor: rows.length === pageLimit(request.query) ? rows.at(-1).id : null,
    };
  });
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
      await projectDocument(company, await projectionBasis(doc));
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
      await projectDocument(company, await projectionBasis(doc));
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
      await projectDocument(company, await projectionBasis(doc));
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
  route('POST', '/:id/payments', (request) =>
    command(request, 'documents.settle', 'document.payment', async (company) => {
      await access(request, 'wallets.transact');
      const doc = await get(company.id, request.params.id);
      if (!['ISSUED', 'POSTED'].includes(doc.status)) fail(409, 'document_not_posted');
      const body = object(request.body),
        amount = integer(body.amount, 'amount', 1),
        walletId = text(body.walletId, 'walletId'),
        id = randomUUID(),
        date = businessDate(body.businessDate ?? company.businessDate, company.timezone);
      const wallet = await db
        .prepare('SELECT * FROM wallets WHERE company_id=? AND id=?')
        .get(company.id, walletId);
      if (!wallet) fail(404, 'wallet_not_found');
      const current = await dto(doc);
      if (amount > current.outstanding) fail(409, 'overpayment');
      const basis = await projectionBasis(doc),
        sale = basis.kind !== 'PURCHASE_ACT',
        advance = basis.kind === 'SALE_INVOICE' || basis.status !== 'POSTED' || date < basis.business_date;
      const account = sale
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
        description: `Оплата ${doc.number}`,
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
          'INSERT INTO commercial_payments(id,company_id,document_id,wallet_id,amount,business_date,journal_id,created_at) VALUES(?,?,?,?,?,?,?,?)',
        )
        .run(id, company.id, doc.id, walletId, amount, date, entry.id, now());
      await db
        .prepare(
          'INSERT INTO wallet_entries(id,company_id,wallet_id,amount,kind,reference_id,created_at,journal_id) VALUES(?,?,?,?,?,?,?,?)',
        )
        .run(
          randomUUID(),
          company.id,
          walletId,
          sale ? amount : -amount,
          'DOCUMENT_PAYMENT',
          id,
          now(),
          entry.id,
        );
      await projectDocument(company, basis);
      return { id, document: await dto(await get(company.id, doc.id)) };
    }),
  );
  route('PUT', '/:id/payments/:paymentId', (request) =>
    command(request, 'documents.settle', 'document.payment.edit', async (company) => {
      await access(request, 'wallets.transact');
      const doc = await get(company.id, request.params.id),
        body = object(request.body);
      const old = await db
        .prepare('SELECT * FROM commercial_payments WHERE company_id=? AND document_id=? AND id=?')
        .get(company.id, doc.id, request.params.paymentId);
      if (!old) fail(404, 'payment_not_found');
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
        .prepare('UPDATE commercial_payments SET amount=?,wallet_id=?,business_date=? WHERE id=?')
        .run(amount, walletId, date, old.id);
      await projectDocument(company, await projectionBasis(doc));
      await db
        .prepare('UPDATE wallet_entries SET wallet_id=?,amount=? WHERE company_id=? AND journal_id=?')
        .run(walletId, doc.kind === 'PURCHASE_ACT' ? -amount : amount, company.id, old.journal_id);
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
        if (old.voided === voided) return { id: old.id, document: await dto(doc) };
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
          .prepare('UPDATE commercial_payments SET voided=?,void_journal_id=? WHERE id=?')
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
        await projectDocument(company, await projectionBasis(doc));
        return { id: old.id, document: await dto(doc) };
      }),
    );
  route('GET', '/:id/payments', async (request) => {
    await access(request, 'documents.read');
    const doc = await get(request.params.companyId, request.params.id);
    return {
      items: await db
        .prepare(
          'SELECT * FROM commercial_payments WHERE company_id=? AND (document_id=? OR document_id=?) ORDER BY business_date,id',
        )
        .all(doc.company_id, doc.id, doc.source_invoice_id ?? doc.id),
    };
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
    const html = `<!doctype html><html lang="ru"><meta charset="utf-8"><title>${escape(doc.number)}</title><body><h1>${labels[doc.kind]} № ${escape(doc.number)}</h1><p>от ${escape(doc.business_date)} · ${escape(doc.status)}</p><p>Исполнитель / фирма: ${escape(d.issuer.legal_name)} · БИН/ИИН ${escape(d.issuer.identifier)}</p><p>Контрагент: ${escape(d.counterparty.name)} · ${escape(d.counterparty.identifier ?? d.counterparty.bin ?? '')}</p><table border="1" cellpadding="8"><thead><tr><th>Услуга</th><th>Ед.</th><th>Количество</th><th>Цена без НДС</th><th>Без НДС</th><th>НДС</th><th>Итого</th></tr></thead><tbody>${d.items.map((l) => `<tr><td>${escape(l.description)}</td><td>${escape(l.unit)}</td><td>${escape(l.quantity)}</td><td>${money(l.unitPrice)}</td><td>${money(l.net)}</td><td>${money(l.vat)}</td><td>${money(l.total)}</td></tr>`).join('')}</tbody></table><p>Без НДС: ${money(d.net)} · НДС: ${money(d.vat)} · Итого: ${money(d.total)}</p><p>${escape(d.vatReason)}</p><p>${escape(d.note)}</p><p>Ответственные лица / подписи: __________________________</p><p>Внутренняя печатная форма. Не является ЭСФ или фискальным чеком. Подписи не проставлены.</p></body></html>`;
    // HTML contains escaped text and no executable content. API-wide CSP remains default-src none.
    reply
      .type('text/html; charset=utf-8')
      .header('Content-Disposition', `inline; filename="document-${doc.id}.html"`);
    return html;
  });
}
