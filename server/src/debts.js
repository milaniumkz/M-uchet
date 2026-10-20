import { readSnapshot } from "./db.js";
import { randomUUID } from "node:crypto";
import { fail, text, integer, scope, businessDate } from "./security.js";
import {
  postJournal,
  normalizeLines,
  projectReference,
  syncWalletBalances,
} from "./accounting.js";

const checked = (value) => {
  if (
    value > BigInt(Number.MAX_SAFE_INTEGER) ||
    value < BigInt(Number.MIN_SAFE_INTEGER)
  )
    fail(422, "report_amount_overflow");
  return Number(value);
};
const max = (a, b) => (a > b ? a : b),
  min = (a, b) => (a < b ? a : b);
const effect = (debt, payment) =>
  BigInt(payment.amount) *
  (payment.direction === (debt.type === "AR" ? "IN" : "OUT") ? 1n : -1n);
const cashAmount = (payment) =>
  payment.amount * (payment.direction === "IN" ? 1 : -1);
export async function debtSource(db, companyId, journalId) {
  return db
    .prepare(
      "SELECT debt_id,payment_id FROM debt_postings WHERE company_id=? AND journal_id=?",
    )
    .get(companyId, journalId);
}
export function registerDebtRoutes(
  app,
  { db, auth, access, command, object, pageLimit },
) {
  const route = (method, path, handler) =>
    app.route({
      method,
      url: "/v1/companies/:companyId/debts" + path,
      preHandler: auth,
      handler:
        method === "GET"
          ? (request, reply) => readSnapshot(db, () => handler(request, reply))
          : handler,
    });
  const get = async (companyId, id) => {
    const row = await db
      .prepare("SELECT * FROM debts WHERE company_id=? AND id=?")
      .get(companyId, text(id, "debtId"));
    if (!row) fail(404, "debt_not_found");
    return row;
  };
  const payments = async (debt) =>
    db
      .prepare(
        "SELECT * FROM debt_payments WHERE company_id=? AND debt_id=? ORDER BY business_date,created_at,id",
      )
      .all(debt.company_id, debt.id);
  const totals = (debt, rows) => {
    let paid = 0n,
      received = 0n,
      paidOut = 0n;
    for (const p of rows)
      if (!p.voided) {
        paid += effect(debt, p);
        if (p.direction === "IN") received += BigInt(p.amount);
        else paidOut += BigInt(p.amount);
      }
    const total = debt.status === "ACTIVE" ? BigInt(debt.total) : 0n;
    return {
      paid: checked(paid),
      received: checked(received),
      paidOut: checked(paidOut),
      remaining: checked(max(0n, total - paid)),
      advance: checked(max(0n, paid - total)),
    };
  };
  const sourceState = async (debt, rows) => {
    const missing = [];
    const mismatches = [];
    const opening = await db
      .prepare(
        "SELECT j.lines FROM debt_postings p JOIN journal j ON j.company_id=p.company_id AND j.id=p.journal_id WHERE p.company_id=? AND p.debt_id=? AND p.kind='OPENING' AND p.active",
      )
      .all(debt.company_id, debt.id);
    const anyOpening = await db
      .prepare(
        "SELECT 1 FROM debt_postings WHERE company_id=? AND debt_id=? AND kind='OPENING' LIMIT 1",
      )
      .get(debt.company_id, debt.id);
    if (!anyOpening) missing.push({ kind: "OPENING", id: debt.id });
    if (debt.data.legacyImported) {
      if (
        await db
          .prepare(
            "SELECT 1 FROM debt_postings WHERE company_id=? AND debt_id=? AND kind='LEGACY_REVERSAL' LIMIT 1",
          )
          .get(debt.company_id, debt.id)
      )
        missing.push({ kind: "LEGACY_REVERSAL_REVIEW", id: debt.id });
      if (
        opening.some((j) =>
          JSON.parse(j.lines).some((l) => l.account.startsWith("wallet:")),
        )
      )
        missing.push({ kind: "LEGACY_OPENING_CASH_REVIEW", id: debt.id });
      const expected = debt.status === "ACTIVE" ? debt.total : 0;
      const actual = opening.reduce(
        (sum, j) =>
          sum +
          JSON.parse(j.lines)
            .filter(
              (l) =>
                l.account === (debt.type === "AR" ? "receivables" : "payables"),
            )
            .reduce(
              (n, l) =>
                n +
                (debt.type === "AR" ? l.debit - l.credit : l.credit - l.debit),
              0,
            ),
        0,
      );
      if (actual !== expected)
        mismatches.push({
          kind: "OPENING",
          storedAmount: expected,
          ledgerAmount: actual,
        });
    }
    for (const p of rows) {
      if (!p.journal_id) {
        missing.push({ kind: "PAYMENT", id: p.id });
        continue;
      }
      if (debt.data.legacyImported && !p.voided) {
        const j = await db
          .prepare("SELECT lines FROM journal WHERE company_id=? AND id=?")
          .get(debt.company_id, p.journal_id);
        const register = await db
          .prepare(
            "SELECT wallet_id,amount FROM wallet_entries WHERE company_id=? AND journal_id=?",
          )
          .all(debt.company_id, p.journal_id);
        if (register.length !== 1 || register[0].wallet_id !== p.wallet_id)
          missing.push({ kind: "LEGACY_WALLET_REGISTER_REVIEW", id: p.id });
        const actual = JSON.parse(j.lines)
          .filter((l) => l.account === `wallet:${p.wallet_id}`)
          .reduce((sum, l) => sum + l.debit - l.credit, 0);
        if (register.length === 1 && register[0].amount !== actual)
          missing.push({ kind: "LEGACY_WALLET_REGISTER_REVIEW", id: p.id });
        if (actual !== cashAmount(p))
          mismatches.push({
            kind: "PAYMENT",
            id: p.id,
            storedAmount: cashAmount(p),
            ledgerAmount: actual,
          });
      }
    }
    return {
      sourceComplete: missing.length === 0,
      missingSources: missing,
      sourceMismatches: mismatches,
    };
  };
  const dto = async (debt, { includePayments = false } = {}) => {
    const rows = await payments(debt);
    return {
      ...debt,
      ...totals(debt, rows),
      ...(includePayments ? { payments: rows } : {}),
      ...(await sourceState(debt, rows)),
      projectId: debt.project_id,
      businessDate: debt.business_date,
      dueDate: debt.due_date,
      counterpartyId: debt.counterparty_id,
    };
  };
  const requireSources = async (debt, body) => {
    const state = await sourceState(debt, await payments(debt));
    if (!state.sourceComplete) fail(422, "debt_source_reconciliation_required");
    if (state.sourceMismatches.length && body.confirmRecalculation !== true)
      fail(422, "debt_reconciliation_confirmation_required");
  };
  const history = async (request, kind, id, value) =>
    db
      .prepare(
        "INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)",
      )
      .run(
        request.params.companyId,
        kind,
        id,
        JSON.stringify(value),
        request.user.id,
      );
  const wallet = async (company, id, ledgerScope) => {
    const row = await db
      .prepare("SELECT * FROM wallets WHERE company_id=? AND id=?")
      .get(company.id, text(id, "walletId"));
    if (!row) fail(404, "wallet_not_found");
    if (row.scope !== ledgerScope) fail(400, "incompatible_ledger_scope");
    return row;
  };
  const record = async (
    company,
    debt,
    kind,
    date,
    lines,
    { active = true, paymentId = null } = {},
  ) => {
    const j = await postJournal(db, company, {
      scope: debt.scope,
      projectId: debt.project_id,
      businessDate: date,
      description: `${kind}: начальный долг ${debt.id}`,
      lines,
    });
    await db
      .prepare(
        "INSERT INTO debt_postings(company_id,debt_id,journal_id,kind,active,payment_id) VALUES(?,?,?,?,?,?)",
      )
      .run(company.id, debt.id, j.id, kind, active, paymentId);
    return j;
  };
  const writeCashEntry = async (company, payment, journal) => {
    const old = await db
      .prepare(
        "SELECT * FROM wallet_entries WHERE company_id=? AND reference_id=? AND journal_id=?",
      )
      .get(company.id, payment.id, journal.id);
    if (old) {
      await db
        .prepare("UPDATE wallet_entries SET wallet_id=?,amount=? WHERE id=?")
        .run(payment.wallet_id, cashAmount(payment), old.id);
    } else
      await db
        .prepare(
          "INSERT INTO wallet_entries(id,company_id,wallet_id,amount,kind,reference_id,created_at,journal_id) VALUES(?,?,?,?,?,?,?,?)",
        )
        .run(
          randomUUID(),
          company.id,
          payment.wallet_id,
          cashAmount(payment),
          "DEBT_PAYMENT",
          payment.id,
          new Date().toISOString(),
          journal.id,
        );
  };
  const replaceJournal = async (company, id, debt, payment, lines) => {
    const normalized = normalizeLines({ lines }),
      old = await db
        .prepare("SELECT * FROM journal WHERE company_id=? AND id=?")
        .get(company.id, id);
    if (!old) fail(422, "debt_source_reconciliation_required");
    if (
      old.lines !== JSON.stringify(normalized) ||
      old.project_id !== debt.project_id ||
      old.scope !== debt.scope ||
      old.business_date !== payment.business_date
    ) {
      await db
        .prepare("SELECT set_config('app.edit_reason',?,true)")
        .get("Пересчёт оплаты начального долга");
      await db
        .prepare(
          "UPDATE journal SET lines=?,project_id=?,scope=?,business_date=? WHERE id=?",
        )
        .run(
          JSON.stringify(normalized),
          debt.project_id,
          debt.scope,
          payment.business_date,
          id,
        );
      await db.prepare("DELETE FROM journal_lines WHERE entry_id=?").run(id);
      for (const [index, line] of normalized.entries())
        await db
          .prepare("INSERT INTO journal_lines VALUES(?,?,?,?,?)")
          .run(id, index, line.account, line.debit, line.credit);
      await syncWalletBalances(db, company.id, [
        ...JSON.parse(old.lines),
        ...normalized,
      ]);
    }
    await writeCashEntry(company, payment, { id });
  };
  const advanceAccount = (debt) =>
    debt.type === "AR" ? "customer_advances" : "supplier_advances";
  const debtAccount = (debt) =>
    debt.type === "AR" ? "receivables" : "payables";
  const cashLines = (debt, payment, paidBefore) => {
    const paid = effect(debt, payment),
      size = BigInt(payment.amount),
      base =
        payment.business_date < debt.business_date || debt.status !== "ACTIVE"
          ? 0n
          : BigInt(debt.total);
    const against =
      paid > 0n
        ? min(size, max(0n, base - paidBefore))
        : min(size, max(0n, paidBefore - base));
    const balances = new Map();
    const line = (account, value) => {
      if (value) balances.set(account, (balances.get(account) ?? 0n) + value);
    };
    line(`wallet:${payment.wallet_id}`, BigInt(cashAmount(payment)));
    if (paid > 0n) {
      line(debtAccount(debt), against * (debt.type === "AR" ? -1n : 1n));
      line(
        advanceAccount(debt),
        (size - against) * (debt.type === "AR" ? -1n : 1n),
      );
    } else {
      line(advanceAccount(debt), against * (debt.type === "AR" ? 1n : -1n));
      line(
        debtAccount(debt),
        (size - against) * (debt.type === "AR" ? 1n : -1n),
      );
    }
    return [...balances].map(([account, value]) => ({
      account,
      debit: value > 0n ? checked(value) : 0,
      credit: value < 0n ? checked(-value) : 0,
    }));
  };
  const rebuild = async (company, debt, { bump = true } = {}) => {
    const old = await db
      .prepare(
        "SELECT p.journal_id,j.* FROM debt_postings p JOIN journal j ON j.company_id=p.company_id AND j.id=p.journal_id WHERE p.company_id=? AND p.debt_id=? AND p.active AND p.kind IN ('OPENING','ALLOCATION')",
      )
      .all(company.id, debt.id);
    for (const j of old)
      await record(
        company,
        { ...debt, scope: j.scope, project_id: j.project_id },
        "REVERSAL",
        j.business_date,
        JSON.parse(j.lines).map((l) => ({
          account: l.account,
          debit: l.credit,
          credit: l.debit,
        })),
        { active: false },
      );
    await db
      .prepare(
        "UPDATE debt_postings SET active=FALSE WHERE company_id=? AND debt_id=? AND active AND kind IN ('OPENING','ALLOCATION')",
      )
      .run(company.id, debt.id);
    if (debt.status === "ACTIVE")
      await record(
        company,
        debt,
        "OPENING",
        debt.business_date,
        debt.type === "AR"
          ? [
              { account: "receivables", debit: debt.total },
              { account: "opening_balances", credit: debt.total },
            ]
          : [
              { account: "opening_balances", debit: debt.total },
              { account: "payables", credit: debt.total },
            ],
      );
    const rows = await payments(debt);
    let paid = 0n,
      prepaid = 0n;
    for (const p of rows)
      if (!p.voided) {
        await wallet(company, p.wallet_id, debt.scope);
        if (!p.journal_id) fail(422, "debt_source_reconciliation_required");
        await replaceJournal(
          company,
          p.journal_id,
          debt,
          p,
          cashLines(debt, p, paid),
        );
        paid += effect(debt, p);
        if (p.business_date < debt.business_date) prepaid += effect(debt, p);
      }
    const applied =
      debt.status === "ACTIVE" ? min(BigInt(debt.total), max(0n, prepaid)) : 0n;
    if (applied)
      await record(
        company,
        debt,
        "ALLOCATION",
        debt.business_date,
        debt.type === "AR"
          ? [
              { account: "customer_advances", debit: checked(applied) },
              { account: "receivables", credit: checked(applied) },
            ]
          : [
              { account: "payables", debit: checked(applied) },
              { account: "supplier_advances", credit: checked(applied) },
            ],
      );
    const value = totals(debt, rows);
    await db
      .prepare(
        "UPDATE debts SET remaining=?,version=version+?,data=? WHERE id=?",
      )
      .run(
        value.remaining,
        bump ? 1 : 0,
        JSON.stringify({ ...debt.data, legacyImported: false }),
        debt.id,
      );
    return dto(await get(company.id, debt.id));
  };
  const input = async (company, body, previous) => {
    if (!["AR", "AP"].includes(body.type)) fail(400, "invalid_debt_type");
    const amount = integer(body.amount, "amount", 1),
      counterpartyId = text(body.counterpartyId, "counterpartyId");
    let party = previous?.data.counterparty;
    if (
      !previous ||
      body.type !== previous.type ||
      counterpartyId !== previous.counterparty_id ||
      body.refreshCounterparty === true
    ) {
      const row = await db
        .prepare(
          "SELECT data FROM documents WHERE company_id=? AND kind=? AND id=?",
        )
        .get(
          company.id,
          body.type === "AR" ? "clients" : "suppliers",
          counterpartyId,
        );
      if (!row) fail(404, "counterparty_not_found");
      party = JSON.parse(row.data);
    }
    const notes = body.notes ?? previous?.data.notes ?? "";
    if (typeof notes !== "string" || notes.length > 2000)
      fail(400, "invalid_notes");
    return {
      type: body.type,
      total: amount,
      counterparty_id: counterpartyId,
      scope: scope(body.scope ?? previous?.scope),
      project_id: await projectReference(
        db,
        company.id,
        body.projectId === undefined ? previous?.project_id : body.projectId,
      ),
      business_date: businessDate(
        body.businessDate ?? previous?.business_date ?? company.businessDate,
        company.timezone,
      ),
      due_date:
        body.dueDate === null || body.dueDate === ""
          ? null
          : body.dueDate === undefined
            ? (previous?.due_date ?? null)
            : businessDate(body.dueDate),
      data: {
        counterparty: party,
        notes: notes.trim(),
        legacyImported: previous?.data.legacyImported ?? false,
      },
    };
  };
  const paymentInput = async (company, debt, body, previous) => {
    if (body.debtVersion !== undefined && body.debtVersion !== debt.version)
      fail(409, "version_conflict");
    const walletId = body.walletId ?? previous?.wallet_id;
    await wallet(company, walletId, debt.scope);
    const direction =
      body.direction ??
      previous?.direction ??
      (debt.type === "AR" ? "IN" : "OUT");
    if (!["IN", "OUT"].includes(direction))
      fail(400, "invalid_payment_direction");
    return {
      wallet_id: walletId,
      amount: integer(body.amount ?? previous?.amount, "amount", 1),
      direction,
      business_date: businessDate(
        body.businessDate ?? previous?.business_date ?? company.businessDate,
        company.timezone,
      ),
    };
  };
  const checkAdvance = async (debt, next, previous, body) => {
    const rows = await payments(debt),
      old = totals(debt, rows).advance;
    const updated = previous
      ? rows.map((p) => (p.id === previous.id ? { ...p, ...next } : p))
      : [...rows, { ...next, voided: false }];
    if (totals(debt, updated).advance > old && body.allowAdvance !== true)
      fail(409, "overpayment");
  };
  const cash = async (company, debt, payment) => {
    const j = await record(
      company,
      debt,
      "PAYMENT",
      payment.business_date,
      cashLines(debt, payment, 0n),
      { paymentId: payment.id },
    );
    await db
      .prepare(
        "UPDATE debt_payments SET journal_id=?,void_journal_id=NULL WHERE id=?",
      )
      .run(j.id, payment.id);
    await writeCashEntry(company, payment, j);
    return j;
  };
  route("GET", "", async (request) => {
    const company = await access(request, "debts.read"),
      selected = request.query.projectId;
    if (selected !== undefined && selected !== "unassigned")
      await projectReference(db, company.id, selected);
    const selectedScope = request.query.scope;
    if (selectedScope !== undefined) scope(selectedScope);
    const type = request.query.type;
    if (type !== undefined && !["AR", "AP"].includes(type))
      fail(400, "invalid_debt_type");
    const status = request.query.status;
    if (status !== undefined && !["ACTIVE", "CANCELLED"].includes(status))
      fail(400, "invalid_debt_status");
    const search =
      typeof request.query.q === "string" ? request.query.q.trim() : "";
    if (search.length > 200) fail(400, "invalid_search");
    if (
      request.query.overdue !== undefined &&
      !["true", "false"].includes(request.query.overdue)
    )
      fail(400, "invalid_overdue");
    const today = businessDate(undefined, company.timezone),
      pattern = "%" + search.replace(/[\\%_]/g, (c) => "\\" + c) + "%";
    const filters = [
      company.id,
      ...(selectedScope ? [selectedScope] : []),
      ...(selected !== undefined
        ? [selected === "unassigned" ? null : selected]
        : []),
      ...(type ? [type] : []),
      ...(status ? [status] : []),
      ...(search ? [pattern, pattern, pattern, pattern] : []),
      ...(request.query.overdue === "true" ? [today] : []),
    ];
    const where = `d.company_id=?${selectedScope ? " AND d.scope IN (?,'BOTH')" : ""}${selected !== undefined ? " AND d.project_id IS NOT DISTINCT FROM ?" : ""}${type ? " AND d.type=?" : ""}${status ? " AND d.status=?" : ""}${search ? " AND (d.data->'counterparty'->>'name' ILIKE ? OR d.data->'counterparty'->>'identifier' ILIKE ? OR d.data->>'notes' ILIKE ? OR d.id ILIKE ?)" : ""}${request.query.overdue === "true" ? " AND d.remaining>0 AND d.due_date IS NOT NULL AND d.due_date<?" : ""}`;
    const limit = pageLimit(request.query),
      rows = await db
        .prepare(
          `SELECT d.* FROM debts d WHERE ${where} AND d.id>? ORDER BY d.id LIMIT ?`,
        )
        .all(...filters, request.query.after ?? "", limit);
    const summary = selectedScope
      ? await db
          .prepare(
            `WITH selected AS(SELECT d.*,COALESCE((SELECT SUM(CASE WHEN p.direction=CASE WHEN d.type='AR' THEN 'IN' ELSE 'OUT' END THEN p.amount ELSE -p.amount END) FROM debt_payments p WHERE p.company_id=d.company_id AND p.debt_id=d.id AND NOT p.voided),0) AS settled FROM debts d WHERE ${where}) SELECT type,count(*) AS count,COALESCE(sum(remaining),0)::text AS outstanding,COALESCE(sum(greatest(0,settled-CASE WHEN status='ACTIVE' THEN total ELSE 0 END)),0)::text AS advance FROM selected GROUP BY type`,
          )
          .all(...filters)
      : null;
    return {
      items: await Promise.all(rows.map((row) => dto(row))),
      summary:
        summary?.map((r) => ({
          ...r,
          outstanding: checked(BigInt(r.outstanding)),
          advance: checked(BigInt(r.advance)),
        })) ?? null,
      scope: selectedScope ?? null,
      businessDate: today,
      nextCursor: rows.length === limit ? rows.at(-1).id : null,
    };
  });
  const readHistory = async (companyId, id) =>
    db
      .prepare(
        "SELECT h.*,u.name AS actor_name FROM entity_history h JOIN users u ON u.id=h.actor_id WHERE h.company_id=? AND ((h.kind='opening_debt' AND h.entity_id=?) OR(h.kind='debt_payment' AND h.entity_id IN(SELECT id FROM debt_payments WHERE company_id=? AND debt_id=?))) ORDER BY h.revision DESC LIMIT 200",
      )
      .all(companyId, id, companyId, id);
  const movements = async (companyId, id) =>
    (
      await db
        .prepare(
          "SELECT p.*,j.business_date,j.project_id,j.description,j.lines,j.created_at FROM debt_postings p JOIN journal j ON j.company_id=p.company_id AND j.id=p.journal_id WHERE p.company_id=? AND p.debt_id=? ORDER BY j.created_at DESC,j.id DESC LIMIT 200",
        )
        .all(companyId, id)
    ).map((row) => ({ ...row, lines: JSON.parse(row.lines) }));
  route("GET", "/:id", async (request) => {
    const company = await access(request, "debts.read");
    return {
      ...(await dto(await get(company.id, request.params.id), {
        includePayments: true,
      })),
      movements: await movements(company.id, request.params.id),
      history: await readHistory(company.id, request.params.id),
      historyLimit: 200,
      movementLimit: 200,
      companyName: company.name,
      companyBusinessDate: businessDate(undefined, company.timezone),
      snapshotAt: new Date().toISOString(),
    };
  });
  route("POST", "", (request) =>
    command(request, "debts.write", "debt.create", async (company) => {
      const d = await input(company, object(request.body)),
        id = randomUUID();
      await db
        .prepare(
          "INSERT INTO debts(id,company_id,type,counterparty_id,total,remaining,scope,due_date,created_at,project_id,business_date,data) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
        )
        .run(
          id,
          company.id,
          d.type,
          d.counterparty_id,
          d.total,
          d.total,
          d.scope,
          d.due_date,
          new Date().toISOString(),
          d.project_id,
          d.business_date,
          JSON.stringify(d.data),
        );
      return rebuild(company, await get(company.id, id), { bump: false });
    }),
  );
  route("PUT", "/:id", (request) =>
    command(request, "debts.write", "debt.edit", async (company) => {
      const old = await get(company.id, request.params.id),
        body = object(request.body);
      if (body.version !== old.version) fail(409, "version_conflict");
      await requireSources(old, body);
      if ((await payments(old)).some((p) => !p.voided))
        await access(request, "debts.settle");
      const d = await input(company, body, old);
      await history(request, "opening_debt", old.id, old);
      await db
        .prepare(
          "UPDATE debts SET type=?,counterparty_id=?,total=?,scope=?,due_date=?,project_id=?,business_date=?,data=? WHERE id=?",
        )
        .run(
          d.type,
          d.counterparty_id,
          d.total,
          d.scope,
          d.due_date,
          d.project_id,
          d.business_date,
          JSON.stringify(d.data),
          old.id,
        );
      return rebuild(company, await get(company.id, old.id));
    }),
  );
  for (const [action, status] of [
    ["cancel", "CANCELLED"],
    ["restore", "ACTIVE"],
  ])
    route("POST", `/:id/${action}`, (request) =>
      command(request, "debts.write", `debt.${action}`, async (company) => {
        const old = await get(company.id, request.params.id),
          body = object(request.body);
        if (body.version !== old.version) fail(409, "version_conflict");
        await requireSources(old, body);
        if ((await payments(old)).some((p) => !p.voided))
          await access(request, "debts.settle");
        if (old.status === status) return dto(old);
        await history(request, "opening_debt", old.id, old);
        await db
          .prepare("UPDATE debts SET status=? WHERE id=?")
          .run(status, old.id);
        return rebuild(company, await get(company.id, old.id));
      }),
    );
  route("GET", "/:id/payments", async (request) => {
    const company = await access(request, "debts.read"),
      debt = await get(company.id, request.params.id);
    return { items: await payments(debt) };
  });
  route("POST", "/:id/settlements", (request) =>
    command(request, "debts.settle", "debt.settle", async (company) => {
      await access(request, "wallets.transact");
      const debt = await get(company.id, request.params.id),
        body = object(request.body);
      await requireSources(debt, body);
      const d = await paymentInput(company, debt, body);
      await checkAdvance(debt, d, null, body);
      const id = randomUUID();
      await db
        .prepare(
          "INSERT INTO debt_payments(id,company_id,debt_id,wallet_id,amount,created_at,business_date,direction) VALUES(?,?,?,?,?,?,?,?)",
        )
        .run(
          id,
          company.id,
          debt.id,
          d.wallet_id,
          d.amount,
          new Date().toISOString(),
          d.business_date,
          d.direction,
        );
      const p = { ...d, id };
      await cash(company, debt, p);
      const updated = await rebuild(company, debt);
      return {
        id,
        debtId: debt.id,
        remaining: updated.remaining,
        advance: updated.advance,
        debtVersion: updated.version,
      };
    }),
  );
  route("PUT", "/:id/payments/:paymentId", (request) =>
    command(request, "debts.settle", "debt.payment.edit", async (company) => {
      await access(request, "wallets.transact");
      const debt = await get(company.id, request.params.id),
        body = object(request.body);
      await requireSources(debt, body);
      const old = await db
        .prepare(
          "SELECT * FROM debt_payments WHERE company_id=? AND debt_id=? AND id=?",
        )
        .get(company.id, debt.id, request.params.paymentId);
      if (!old) fail(404, "payment_not_found");
      if (body.version !== old.version) fail(409, "version_conflict");
      const d = await paymentInput(company, debt, body, old);
      if (!old.voided) await checkAdvance(debt, d, old, body);
      await history(request, "debt_payment", old.id, old);
      await db
        .prepare(
          "UPDATE debt_payments SET wallet_id=?,amount=?,direction=?,business_date=?,version=version+1 WHERE id=?",
        )
        .run(d.wallet_id, d.amount, d.direction, d.business_date, old.id);
      if (!old.voided) await rebuild(company, debt);
      else
        await db
          .prepare("UPDATE debts SET version=version+1 WHERE id=?")
          .run(debt.id);
      return db.prepare("SELECT * FROM debt_payments WHERE id=?").get(old.id);
    }),
  );
  for (const action of ["void", "restore"])
    route("POST", `/:id/payments/:paymentId/${action}`, (request) =>
      command(
        request,
        "debts.settle",
        `debt.payment.${action}`,
        async (company) => {
          await access(request, "wallets.transact");
          const debt = await get(company.id, request.params.id),
            body = object(request.body);
          await requireSources(debt, body);
          const old = await db
            .prepare(
              "SELECT * FROM debt_payments WHERE company_id=? AND debt_id=? AND id=?",
            )
            .get(company.id, debt.id, request.params.paymentId);
          if (!old) fail(404, "payment_not_found");
          if (body.version !== old.version) fail(409, "version_conflict");
          if (old.voided === (action === "void")) return old;
          await history(request, "debt_payment", old.id, old);
          if (action === "void") {
            const j = await db
              .prepare("SELECT * FROM journal WHERE id=?")
              .get(old.journal_id);
            const reversed = await record(
              company,
              { ...debt, project_id: j.project_id, scope: j.scope },
              "PAYMENT_VOID",
              j.business_date,
              JSON.parse(j.lines).map((l) => ({
                account: l.account,
                debit: l.credit,
                credit: l.debit,
              })),
              { active: false, paymentId: old.id },
            );
            await db
              .prepare(
                "UPDATE debt_postings SET active=FALSE WHERE company_id=? AND journal_id=?",
              )
              .run(company.id, old.journal_id);
            await db
              .prepare(
                "INSERT INTO wallet_entries(id,company_id,wallet_id,amount,kind,reference_id,created_at,journal_id) VALUES(?,?,?,?,?,?,?,?)",
              )
              .run(
                randomUUID(),
                company.id,
                old.wallet_id,
                -cashAmount(old),
                "DEBT_PAYMENT_VOID",
                old.id,
                new Date().toISOString(),
                reversed.id,
              );
            await db
              .prepare(
                "UPDATE debt_payments SET voided=TRUE,void_journal_id=?,version=version+1 WHERE id=?",
              )
              .run(reversed.id, old.id);
          } else {
            await wallet(company, old.wallet_id, debt.scope);
            await checkAdvance(debt, { ...old, voided: false }, old, {
              allowAdvance: body.allowAdvance,
            });
            await db
              .prepare(
                "UPDATE debt_payments SET voided=FALSE,version=version+1 WHERE id=?",
              )
              .run(old.id);
            await cash(company, debt, old);
          }
          await rebuild(company, debt);
          return db
            .prepare("SELECT * FROM debt_payments WHERE id=?")
            .get(old.id);
        },
      ),
    );
  route("GET", "/:id/history", async (request) => {
    const company = await access(request, "debts.read");
    await get(company.id, request.params.id);
    return {
      items: await db
        .prepare(
          "SELECT h.*,u.name AS actor_name FROM entity_history h JOIN users u ON u.id=h.actor_id WHERE h.company_id=? AND ((h.kind='opening_debt' AND h.entity_id=?) OR(h.kind='debt_payment' AND h.entity_id IN(SELECT id FROM debt_payments WHERE company_id=? AND debt_id=?))) ORDER BY h.revision DESC LIMIT 200",
        )
        .all(company.id, request.params.id, company.id, request.params.id),
    };
  });
}
