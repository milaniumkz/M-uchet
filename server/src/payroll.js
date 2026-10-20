import { isDeepStrictEqual } from "node:util";
import { randomUUID } from "node:crypto";
import { businessDate, fail, integer, scope, text } from "./security.js";
import {
  projectReference,
  postJournal,
  syncWalletBalances,
} from "./accounting.js";
import {
  calculatePayroll2026,
  payrollRules2026,
} from "./payroll-calculation.js";
const now = () => new Date().toISOString();
const monthEnd = (month) =>
  new Date(Date.UTC(Number(month.slice(0, 4)), Number(month.slice(5)), 0))
    .toISOString()
    .substring(0, 10);
const nextMonth = (month) =>
  new Date(Date.UTC(Number(month.slice(0, 4)), Number(month.slice(5)), 1))
    .toISOString()
    .substring(0, 7);
const same = isDeepStrictEqual;
export function registerPayrollRoutes(
  app,
  { db, auth, access, command, object, pageLimit },
) {
  const base = "/v1/companies/:companyId/payroll";
  const route = (method, path, handler) =>
    app.route({ method, url: base + path, preHandler: auth, handler });
  const employee = async (companyId, id) => {
    const e = await db
      .prepare("SELECT * FROM employees WHERE company_id=? AND id=?")
      .get(companyId, text(id, "employeeId"));
    if (!e) fail(404, "employee_not_found");
    return e;
  };
  const record = async (companyId, id) => {
    const r = await db
      .prepare("SELECT * FROM payroll_records WHERE company_id=? AND id=?")
      .get(companyId, text(id, "payrollId"));
    if (!r) fail(404, "payroll_not_found");
    return r;
  };
  const history = async (companyId, kind, id, snapshot, actor) =>
    db
      .prepare(
        "INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)",
      )
      .run(companyId, kind, id, JSON.stringify(snapshot), actor);
  const parseInput = async (company, body, previous, checkVersions = false) => {
    if (company.currency !== "KZT") fail(422, "payroll_currency_not_supported");
    const e = await employee(
        company.id,
        previous?.employee_id ?? body.employeeId,
      ),
      month = previous?.month ?? body.month;
    if (typeof month !== "string" || !/^2026-(0[1-9]|1[0-2])$/.test(month))
      fail(422, "payroll_rule_period_not_supported");
    if (
      (previous && body.month !== undefined && body.month !== previous.month) ||
      (previous &&
        body.employeeId !== undefined &&
        body.employeeId !== previous.employee_id)
    )
      fail(400, "payroll_identity_change_requires_new_record");
    const settings =
      previous && body.refreshCompany !== true
        ? previous.data.input.company
        : await db
            .prepare("SELECT * FROM company_settings WHERE company_id=?")
            .get(company.id);
    if (!settings) fail(422, "company_settings_required");
    const firm = {
      currency: company.currency,
      legalName: settings.legalName ?? settings.legal_name ?? company.name,
      identifier: settings.identifier ?? null,
      legalForm: settings.legalForm ?? settings.legal_form,
      taxRegime: settings.taxRegime ?? settings.tax_regime,
      version: settings.version ?? 0,
    };
    const oldProfile = previous?.data.input.employee;
    const person =
      oldProfile && body.refreshEmployee !== true
        ? { ...oldProfile }
        : {
            name: e.name,
            identifier: e.identifier,
            hireDate: e.hire_date,
            birthDate: e.birth_date,
            terminationDate: e.termination_date,
            resident: e.data.resident,
            citizenship: e.data.citizenship,
            standardDeductionDeclaration: e.data.standardDeductionDeclaration,
            sex: e.data.sex,
            version: e.version,
          };
    person.sex = Object.hasOwn(body, "sex") ? body.sex : person.sex;
    person.specialCategory = "NONE";
    if (
      checkVersions &&
      ((body.expectedCompanyVersion !== undefined &&
        body.expectedCompanyVersion !== firm.version) ||
        (body.expectedEmployeeVersion !== undefined &&
          body.expectedEmployeeVersion !== person.version))
    )
      fail(409, "version_conflict");
    if (body.standardDeductionDeclaration !== undefined) {
      if (typeof body.standardDeductionDeclaration !== "boolean")
        fail(400, "invalid_employee_profile");
      person.standardDeductionDeclaration = body.standardDeductionDeclaration;
    }
    const input = {
      month,
      gross: integer(
        body.gross ?? previous?.data.input.gross ?? e.gross_base,
        "gross",
      ),
      category: body.category ?? previous?.data.input.category,
      singleEmployer:
        body.singleEmployer ?? previous?.data.input.singleEmployer,
      company: firm,
      employee: person,
    };
    // Validate facts and date without inventing prior income. The actual context is
    // supplied by the sequence below, not accepted from the preview/save request.
    calculatePayroll2026({ ...input, prior: {} });
    return {
      employeeId: e.id,
      month,
      projectId: await projectReference(
        db,
        company.id,
        Object.hasOwn(body, "projectId")
          ? body.projectId
          : previous
            ? previous.project_id
            : e.project_id,
      ),
      scope: scope(body.scope ?? previous?.scope),
      input,
      businessDate: businessDate(
        body.businessDate ?? previous?.data.businessDate ?? monthEnd(month),
        company.timezone,
      ),
      policyAcknowledged:
        body.policyAcknowledged === undefined
          ? previous?.data.policyAcknowledged === true
          : body.policyAcknowledged === true,
      note:
        body.note === undefined
          ? (previous?.data.note ?? "")
          : body.note === ""
            ? ""
            : text(body.note, "note", 2000),
    };
  };
  const sequence = async (companyId, employeeId, candidate) => {
    const e = await employee(companyId, employeeId),
      opening = await db
        .prepare(
          "SELECT * FROM payroll_openings WHERE company_id=? AND employee_id=? AND year=2026",
        )
        .get(companyId, employeeId);
    let expected = opening
        ? nextMonth(opening.through_month)
        : e.hire_date < "2026-01-01"
          ? "2026-01"
          : e.hire_date.substring(0, 7),
      prior = opening?.data.context ?? {};
    let rows = await db
      .prepare(
        "SELECT * FROM payroll_records WHERE company_id=? AND employee_id=? AND status<>'DRAFT' ORDER BY month,id",
      )
      .all(companyId, employeeId);
    if (candidate) {
      if (
        rows.some((r) => r.id !== candidate.id && r.month === candidate.month)
      )
        fail(409, "payroll_month_exists");
      rows = rows.filter((r) => r.id !== candidate.id);
      rows.push(candidate);
      rows.sort((a, b) => a.month.localeCompare(b.month));
    }
    const calculated = new Map();
    for (const row of rows) {
      if (
        row.data.ruleVersion &&
        row.data.ruleVersion !== payrollRules2026.version
      )
        fail(422, "payroll_rules_version_unavailable");
      if (opening && row.month <= opening.through_month)
        fail(422, "payroll_month_in_opening");
      if (row.month !== expected)
        fail(422, "payroll_opening_or_missing_month_required");
      const result = calculatePayroll2026({
        ...row.data.input,
        gross: row.status === "CANCELLED" ? 0 : row.data.input.gross,
        prior,
      });
      calculated.set(row.id, result);
      prior = result.ytd;
      expected = nextMonth(row.month);
    }
    return { rows, calculated, opening };
  };
  const dto = async (row) => {
    const paid = (
      await db
        .prepare(
          "SELECT COALESCE(sum(amount),0) AS paid FROM payroll_payments WHERE company_id=? AND payroll_id=? AND NOT voided",
        )
        .get(row.company_id, row.id)
    ).paid;
    const net = row.data.calculation?.net ?? 0;
    return {
      ...row,
      paid,
      outstanding: Math.max(0, net - paid),
      employeeAdvance: Math.max(0, paid - net),
    };
  };
  const reverseActive = async (company, row, kinds) => {
    const old = await db
      .prepare(
        `SELECT p.id,j.* FROM payroll_postings p JOIN journal j ON j.id=p.journal_id WHERE p.company_id=? AND p.payroll_id=? AND p.active=TRUE AND p.kind IN (${kinds.map(() => "?").join(",")})`,
      )
      .all(company.id, row.id, ...kinds);
    for (const entry of old) {
      const reversed = await postJournal(db, company, {
        scope: entry.scope,
        projectId: entry.project_id,
        businessDate: entry.business_date,
        description: `Пересчёт начисления ${row.id}`,
        lines: JSON.parse(entry.lines).map((l) => ({
          account: l.account,
          debit: l.credit,
          credit: l.debit,
        })),
      });
      await db
        .prepare(
          "INSERT INTO payroll_postings(company_id,payroll_id,journal_id,active,kind) VALUES(?,?,?,FALSE,?)",
        )
        .run(company.id, row.id, reversed.id, "REVERSAL");
    }
    await db
      .prepare(
        `UPDATE payroll_postings SET active=FALSE WHERE company_id=? AND payroll_id=? AND active=TRUE AND kind IN (${kinds.map(() => "?").join(",")})`,
      )
      .run(company.id, row.id, ...kinds);
  };
  const posting = async (
    company,
    row,
    kind,
    lines,
    date = row.data.businessDate,
  ) => {
    if (!lines.length) return;
    const entry = await postJournal(db, company, {
      scope: row.scope,
      projectId: row.project_id,
      businessDate: date,
      description: `${kind === "ACCRUAL" ? "Начисление зарплаты" : kind === "EMPLOYER" ? "Взносы работодателя" : "Зачёт зарплатного аванса"} ${row.id}`,
      lines,
    });
    await db
      .prepare(
        "INSERT INTO payroll_postings(company_id,payroll_id,journal_id,kind) VALUES(?,?,?,?)",
      )
      .run(company.id, row.id, entry.id, kind);
    return entry;
  };
  const side = (account, amount, debit) =>
    amount === 0
      ? []
      : [
          {
            account,
            debit: amount > 0 === debit ? Math.abs(amount) : 0,
            credit: amount > 0 !== debit ? Math.abs(amount) : 0,
          },
        ];
  const projectPayments = async (company, row) => {
    await reverseActive(company, row, ["ALLOCATION"]);
    const payments = await db
      .prepare(
        "SELECT p.*,w.scope AS wallet_scope FROM payroll_payments p JOIN wallets w ON w.company_id=p.company_id AND w.id=p.wallet_id WHERE p.company_id=? AND p.payroll_id=? AND NOT p.voided ORDER BY p.business_date,p.created_at,p.id",
      )
      .all(company.id, row.id);
    const net = row.data.calculation?.net ?? 0;
    let paid = 0,
      advance = 0;
    for (const p of payments) {
      if (p.wallet_scope !== row.scope) fail(400, "incompatible_ledger_scope");
      const prepaid = p.business_date < row.data.businessDate,
        debt = prepaid ? 0 : Math.min(p.amount, Math.max(0, net - paid)),
        extra = p.amount - debt;
      const lines = [
        { account: `wallet:${p.wallet_id}`, debit: 0, credit: p.amount },
        ...side("payroll_payable", debt, true),
        ...side("payroll_advances", extra, true),
      ];
      const old = await db
        .prepare("SELECT * FROM journal WHERE company_id=? AND id=?")
        .get(company.id, p.journal_id);
      if (
        old.project_id !== row.project_id ||
        old.scope !== row.scope ||
        old.business_date !== p.business_date ||
        !same(JSON.parse(old.lines), lines)
      ) {
        await db
          .prepare("SELECT set_config('app.edit_reason',?,true)")
          .get("Пересчёт выплаты зарплаты");
        await db
          .prepare(
            "UPDATE journal SET lines=?,project_id=?,scope=?,business_date=? WHERE id=?",
          )
          .run(
            JSON.stringify(lines),
            row.project_id,
            row.scope,
            p.business_date,
            old.id,
          );
        await db
          .prepare("DELETE FROM journal_lines WHERE entry_id=?")
          .run(old.id);
        for (const [position, l] of lines.entries())
          await db
            .prepare("INSERT INTO journal_lines VALUES(?,?,?,?,?)")
            .run(old.id, position, l.account, l.debit, l.credit);
        await syncWalletBalances(db, company.id, [
          ...JSON.parse(old.lines),
          ...lines,
        ]);
      }
      if (prepaid) advance += p.amount;
      paid += p.amount;
    }
    const allocation = Math.min(advance, net);
    if (allocation)
      await posting(company, row, "ALLOCATION", [
        { account: "payroll_payable", debit: allocation },
        { account: "payroll_advances", credit: allocation },
      ]);
    integer(paid, "payrollPaid");
  };
  const projectFinancial = async (company, row) => {
    await reverseActive(company, row, ["ACCRUAL", "EMPLOYER"]);
    const c = row.data.calculation;
    await posting(company, row, "ACCRUAL", [
      ...side("salary_expense", c.gross, true),
      ...side("payroll_payable", c.net, false),
      ...side("payroll_opv", c.opv, false),
      ...side("payroll_vosms", c.vosms, false),
      ...side("payroll_ipn", c.ipn, false),
    ]);
    await posting(company, row, "EMPLOYER", [
      ...side("payroll_employer_expense", c.employerContributions, true),
      ...side("payroll_so", c.so, false),
      ...side("payroll_oosms", c.oosms, false),
      ...side("payroll_opvr", c.opvr, false),
      ...side("payroll_sn", c.sn, false),
    ]);
    await projectPayments(company, row);
  };
  const financial = (row) =>
    JSON.stringify([
      row.scope,
      row.project_id,
      row.data.businessDate,
      ...[
        "gross",
        "net",
        "opv",
        "vosms",
        "ipn",
        "so",
        "oosms",
        "opvr",
        "sn",
      ].map((k) => row.data.calculation?.[k]),
    ]);
  const rebuild = async (company, employeeId, actor) => {
    const seq = await sequence(company.id, employeeId);
    for (const row of seq.rows) {
      const old = structuredClone(row);
      row.data = {
        ...row.data,
        calculation: seq.calculated.get(row.id),
        ruleVersion: payrollRules2026.version,
        ruleSnapshot: payrollRules2026,
      };
      if (!same(old.data, row.data)) {
        await history(company.id, "payroll", row.id, old, actor);
        await db
          .prepare(
            "UPDATE payroll_records SET data=?,version=version+1,updated_at=? WHERE id=?",
          )
          .run(JSON.stringify(row.data), now(), row.id);
      }
      if (
        financial(old) !== financial(row) ||
        !(await db
          .prepare(
            "SELECT 1 FROM payroll_postings WHERE company_id=? AND payroll_id=? AND active=TRUE LIMIT 1",
          )
          .get(company.id, row.id))
      )
        await projectFinancial(company, row);
    }
  };
  route("GET", "/rules", async (request) => {
    const company = await access(request, "payroll.read");
    return {
      ...payrollRules2026,
      businessDate: businessDate(undefined, company.timezone),
    };
  });
  route("GET", "/openings/:employeeId", async (request) => {
    const company = await access(request, "payroll.read");
    await employee(company.id, request.params.employeeId);
    return (
      (await db
        .prepare(
          "SELECT * FROM payroll_openings WHERE company_id=? AND employee_id=? AND year=2026",
        )
        .get(company.id, request.params.employeeId)) ?? {
        employee_id: request.params.employeeId,
        version: 0,
        data: null,
      }
    );
  });
  route("PUT", "/openings/:employeeId", (request) =>
    command(request, "payroll.write", "payroll.opening", async (company) => {
      const e = await employee(company.id, request.params.employeeId),
        body = object(request.body),
        old = await db
          .prepare(
            "SELECT * FROM payroll_openings WHERE company_id=? AND employee_id=? AND year=2026",
          )
          .get(company.id, e.id);
      if (body.version !== (old?.version ?? 0)) fail(409, "version_conflict");
      if (
        typeof body.throughMonth !== "string" ||
        !/^2026-(0[1-9]|1[0-2])$/.test(body.throughMonth)
      )
        fail(400, "invalid_payroll_opening");
      if (body.confirmed !== true)
        fail(422, "payroll_opening_confirmation_required");
      if (
        await db
          .prepare(
            "SELECT 1 FROM payroll_records WHERE company_id=? AND employee_id=? AND month<=? LIMIT 1",
          )
          .get(company.id, e.id, body.throughMonth)
      )
        fail(409, "payroll_opening_overlaps_records");
      const context = Object.fromEntries(
        ["taxableBase", "ipn", "basicUsed", "basicCarry", "opvBase"].map(
          (k) => [k, integer(body[k], "opening_" + k)],
        ),
      );
      const months = Number(body.throughMonth.slice(5));
      if (
        context.basicUsed + context.basicCarry >
          months * 30 * payrollRules2026.mrp ||
        context.opvBase > months * 50 * payrollRules2026.mzp
      )
        fail(400, "invalid_payroll_opening_context");
      const data = {
        context,
        sourceNote: text(body.sourceNote, "sourceNote", 2000),
        confirmed: true,
      };
      if (
        await db
          .prepare(
            "SELECT 1 FROM payroll_records WHERE company_id=? AND employee_id=? AND status<>'DRAFT' LIMIT 1",
          )
          .get(company.id, e.id)
      )
        await access(request, "payroll.post");
      if (old)
        await history(
          company.id,
          "payroll_opening",
          e.id,
          old,
          request.user.id,
        );
      await db
        .prepare(
          "INSERT INTO payroll_openings(company_id,employee_id,year,through_month,data,created_at,updated_at) VALUES(?,?,2026,?,?,?,?) ON CONFLICT(company_id,employee_id,year) DO UPDATE SET through_month=excluded.through_month,data=excluded.data,version=payroll_openings.version+1,updated_at=excluded.updated_at",
        )
        .run(
          company.id,
          e.id,
          body.throughMonth,
          JSON.stringify(data),
          now(),
          now(),
        );
      await rebuild(company, e.id, request.user.id);
      return {
        id: e.id,
        ...(await db
          .prepare(
            "SELECT * FROM payroll_openings WHERE company_id=? AND employee_id=? AND year=2026",
          )
          .get(company.id, e.id)),
      };
    }),
  );
  route("POST", "/preview", async (request) => {
    const company = await access(request, "payroll.write"),
      body = object(request.body),
      previous = body.payrollId
        ? await record(company.id, body.payrollId)
        : null;
    const parsed = await parseInput(company, body, previous),
      candidate = {
        id: previous?.id ?? "PREVIEW",
        company_id: company.id,
        employee_id: parsed.employeeId,
        month: parsed.month,
        status: previous?.status === "CANCELLED" ? "CANCELLED" : "POSTED",
        project_id: parsed.projectId,
        scope: parsed.scope,
        data: parsed,
      };
    const seq = await sequence(company.id, parsed.employeeId, candidate);
    return {
      ...parsed,
      calculation: seq.calculated.get(candidate.id),
      affected: seq.rows
        .filter((r) => r.month > candidate.month)
        .map((r) => ({
          id: r.id,
          month: r.month,
          calculation: seq.calculated.get(r.id),
        })),
      policy: payrollRules2026,
    };
  });
  route("POST", "", (request) =>
    command(request, "payroll.write", "payroll.create", async (company) => {
      const parsed = await parseInput(
          company,
          object(request.body),
          undefined,
          true,
        ),
        id = randomUUID(),
        candidate = {
          id,
          company_id: company.id,
          employee_id: parsed.employeeId,
          month: parsed.month,
          status: "POSTED",
          project_id: parsed.projectId,
          scope: parsed.scope,
          data: parsed,
        };
      const seq = await sequence(company.id, parsed.employeeId, candidate);
      parsed.calculation = seq.calculated.get(id);
      parsed.ruleVersion = payrollRules2026.version;
      parsed.ruleSnapshot = payrollRules2026;
      try {
        await db
          .prepare(
            "INSERT INTO payroll_records(id,company_id,employee_id,month,status,project_id,scope,data,created_at,updated_at) VALUES(?,?,?,?,'DRAFT',?,?,?,?,?)",
          )
          .run(
            id,
            company.id,
            parsed.employeeId,
            parsed.month,
            parsed.projectId,
            parsed.scope,
            JSON.stringify(parsed),
            now(),
            now(),
          );
      } catch (e) {
        if (e.code === "23505") fail(409, "payroll_month_exists");
        throw e;
      }
      return dto(await record(company.id, id));
    }),
  );
  route("GET", "", async (request) => {
    const company = await access(request, "payroll.read"),
      month = request.query.month,
      project = request.query.projectId,
      selectedScope = scope(request.query.scope);
    if (selectedScope === "BOTH") fail(400, "invalid_report_scope");
    if (
      month !== undefined &&
      (typeof month !== "string" || !/^2026-(0[1-9]|1[0-2])$/.test(month))
    )
      fail(400, "invalid_payroll_month");
    if (project !== undefined && project !== "unassigned")
      await projectReference(db, company.id, project);
    const filters = `company_id=? AND scope IN (?,'BOTH')${month === undefined ? "" : " AND month=?"}${project === undefined ? "" : " AND project_id IS NOT DISTINCT FROM ?"}`;
    const params = [
      company.id,
      selectedScope,
      ...(month === undefined ? [] : [month]),
      ...(project === undefined
        ? []
        : [project === "unassigned" ? null : project]),
    ];
    const rows = await db
      .prepare(
        `SELECT * FROM payroll_records WHERE ${filters} AND id>? ORDER BY id LIMIT ?`,
      )
      .all(...params, request.query.after ?? "", pageLimit(request.query));
    const summary = await db
      .prepare(
        `SELECT count(*) AS count,count(*) FILTER(WHERE status='DRAFT') AS drafts,
   COALESCE(sum((data->'calculation'->>'gross')::numeric) FILTER(WHERE status<>'DRAFT'),0) AS gross,
   COALESCE(sum((data->'calculation'->>'net')::numeric) FILTER(WHERE status<>'DRAFT'),0) AS net,
   COALESCE(sum((data->'calculation'->>'employerContributions')::numeric) FILTER(WHERE status<>'DRAFT'),0) AS employer,
   COALESCE(sum((data->'calculation'->>'totalCost')::numeric) FILTER(WHERE status<>'DRAFT'),0) AS total_cost FROM payroll_records WHERE ${filters}`,
      )
      .get(...params);
    return {
      items: await Promise.all(rows.map(dto)),
      summary,
      nextCursor:
        rows.length === pageLimit(request.query) ? rows.at(-1).id : null,
    };
  });
  route("GET", "/:id", async (request) => {
    const company = await access(request, "payroll.read");
    return dto(await record(company.id, request.params.id));
  });
  route("PUT", "/:id", (request) =>
    command(request, "payroll.write", "payroll.edit", async (company) => {
      const old = await record(company.id, request.params.id),
        body = object(request.body);
      if (body.version !== old.version) fail(409, "version_conflict");
      if (old.status !== "DRAFT") await access(request, "payroll.post");
      const parsed = await parseInput(company, body, old, true);
      if (old.status !== "DRAFT" && !parsed.policyAcknowledged)
        fail(422, "payroll_policy_acknowledgement_required");
      const candidate = {
        ...old,
        project_id: parsed.projectId,
        scope: parsed.scope,
        data: parsed,
        status: old.status === "DRAFT" ? "POSTED" : old.status,
      };
      const seq = await sequence(company.id, old.employee_id, candidate);
      parsed.calculation = seq.calculated.get(old.id);
      parsed.ruleVersion = payrollRules2026.version;
      parsed.ruleSnapshot = payrollRules2026;
      await history(
        company.id,
        "payroll",
        old.id,
        {
          ...old,
          reason: text(body.reason ?? "Исправление зарплаты", "reason", 500),
        },
        request.user.id,
      );
      await db
        .prepare(
          "UPDATE payroll_records SET project_id=?,scope=?,data=?,version=version+1,updated_at=? WHERE id=?",
        )
        .run(
          parsed.projectId,
          parsed.scope,
          JSON.stringify(parsed),
          now(),
          old.id,
        );
      if (old.status !== "DRAFT") {
        const row = await record(company.id, old.id);
        await projectFinancial(company, row);
        await rebuild(company, old.employee_id, request.user.id);
      }
      return dto(await record(company.id, old.id));
    }),
  );
  for (const [action, status] of [
    ["post", "POSTED"],
    ["cancel", "CANCELLED"],
    ["restore", "POSTED"],
  ])
    route("POST", `/:id/${action}`, (request) =>
      command(request, "payroll.post", `payroll.${action}`, async (company) => {
        const row = await record(company.id, request.params.id),
          body = object(request.body);
        if (body.version !== row.version) fail(409, "version_conflict");
        if (row.data.policyAcknowledged !== true)
          fail(422, "payroll_policy_acknowledgement_required");
        if (action === "post" && row.status === "DRAFT") {
          const seq = await sequence(company.id, row.employee_id, {
            ...row,
            status: "POSTED",
          });
          if (!same(row.data.calculation, seq.calculated.get(row.id)))
            fail(409, "payroll_calculation_changed");
        }
        if (
          (action === "post" && row.status !== "DRAFT") ||
          (action === "restore" && row.status !== "CANCELLED") ||
          (action === "cancel" && row.status === "CANCELLED")
        )
          fail(409, "invalid_payroll_state");

        await history(company.id, "payroll", row.id, row, request.user.id);
        await db
          .prepare(
            "UPDATE payroll_records SET status=?,version=version+1,updated_at=? WHERE id=?",
          )
          .run(status, now(), row.id);
        // Force projection after DRAFT→POSTED even when the preview totals are equal.
        await rebuild(company, row.employee_id, request.user.id);
        return dto(await record(company.id, row.id));
      }),
    );
  route("GET", "/:id/history", async (request) => {
    const company = await access(request, "payroll.read");
    await record(company.id, request.params.id);
    return {
      items: await db
        .prepare(
          "SELECT h.*,u.name AS actor_name FROM entity_history h JOIN users u ON u.id=h.actor_id WHERE h.company_id=? AND h.kind='payroll' AND h.entity_id=? ORDER BY revision DESC",
        )
        .all(company.id, request.params.id),
    };
  });
  route("GET", "/:id/payments", async (request) => {
    const company = await access(request, "payroll.read");
    await record(company.id, request.params.id);
    return {
      items: await db
        .prepare(
          "SELECT p.*,w.name AS wallet_name FROM payroll_payments p JOIN wallets w ON w.company_id=p.company_id AND w.id=p.wallet_id WHERE p.company_id=? AND p.payroll_id=? ORDER BY p.business_date,p.id",
        )
        .all(company.id, request.params.id),
    };
  });
  route("POST", "/:id/payments", (request) =>
    command(request, "payroll.settle", "payroll.payment", async (company) => {
      await access(request, "wallets.transact");
      const row = await record(company.id, request.params.id),
        body = object(request.body),
        current = await dto(row);
      if (row.status === "DRAFT") fail(409, "payroll_not_posted");
      const amount = integer(body.amount, "amount", 1);
      if (amount > current.outstanding) fail(409, "overpayment");
      const wallet = await db
        .prepare("SELECT * FROM wallets WHERE company_id=? AND id=?")
        .get(company.id, text(body.walletId, "walletId"));
      if (!wallet) fail(404, "wallet_not_found");
      if (wallet.scope !== row.scope) fail(400, "incompatible_ledger_scope");
      const id = randomUUID(),
        date = businessDate(body.businessDate, company.timezone),
        entry = await postJournal(db, company, {
          scope: row.scope,
          projectId: row.project_id,
          businessDate: date,
          description: `Выплата зарплаты ${id}`,
          lines: [
            { account: "payroll_payable", debit: amount },
            { account: `wallet:${wallet.id}`, credit: amount },
          ],
        });
      await db
        .prepare(
          "INSERT INTO payroll_payments(id,company_id,payroll_id,wallet_id,amount,business_date,journal_id,created_at) VALUES(?,?,?,?,?,?,?,?)",
        )
        .run(id, company.id, row.id, wallet.id, amount, date, entry.id, now());
      await db
        .prepare(
          "INSERT INTO wallet_entries(id,company_id,wallet_id,amount,kind,reference_id,created_at,journal_id) VALUES(?,?,?,?,?,?,?,?)",
        )
        .run(
          randomUUID(),
          company.id,
          wallet.id,
          -amount,
          "PAYROLL_PAYMENT",
          id,
          now(),
          entry.id,
        );
      await projectPayments(company, row);
      return { id, payroll: await dto(row) };
    }),
  );
  route("DELETE", "/:id", (request) =>
    command(
      request,
      "payroll.write",
      "payroll.delete_draft",
      async (company) => {
        const row = await record(company.id, request.params.id);
        if (row.status !== "DRAFT")
          fail(409, "payroll_posted_delete_forbidden");
        if (object(request.body).version !== row.version)
          fail(409, "version_conflict");
        await history(company.id, "payroll", row.id, row, request.user.id);
        await db
          .prepare("DELETE FROM payroll_records WHERE company_id=? AND id=?")
          .run(company.id, row.id);
        return { id: row.id, deleted: true };
      },
    ),
  );
  const payment = async (companyId, payrollId, id) => {
    const p = await db
      .prepare(
        "SELECT * FROM payroll_payments WHERE company_id=? AND payroll_id=? AND id=?",
      )
      .get(companyId, payrollId, id);
    if (!p) fail(404, "payment_not_found");
    return p;
  };
  route("PUT", "/:id/payments/:paymentId", (request) =>
    command(
      request,
      "payroll.settle",
      "payroll.payment.edit",
      async (company) => {
        await access(request, "wallets.transact");
        const row = await record(company.id, request.params.id),
          old = await payment(company.id, row.id, request.params.paymentId),
          body = object(request.body);
        if (body.version !== old.version) fail(409, "version_conflict");
        if (old.voided) fail(409, "payment_voided");
        const wallet = await db
          .prepare("SELECT * FROM wallets WHERE company_id=? AND id=?")
          .get(company.id, text(body.walletId ?? old.wallet_id, "walletId"));
        if (!wallet) fail(404, "wallet_not_found");
        if (wallet.scope !== row.scope) fail(400, "incompatible_ledger_scope");
        const amount = integer(body.amount, "amount", 1),
          date = businessDate(
            body.businessDate ?? old.business_date,
            company.timezone,
          );
        await history(
          company.id,
          "payroll_payment",
          old.id,
          {
            ...old,
            reason: text(
              body.reason ?? "Исправление выплаты зарплаты",
              "reason",
              500,
            ),
          },
          request.user.id,
        );
        await db
          .prepare(
            "UPDATE payroll_payments SET amount=?,business_date=?,wallet_id=?,version=version+1 WHERE id=?",
          )
          .run(amount, date, wallet.id, old.id);
        await db
          .prepare(
            "UPDATE wallet_entries SET wallet_id=?,amount=? WHERE company_id=? AND journal_id=?",
          )
          .run(wallet.id, -amount, company.id, old.journal_id);
        await projectPayments(company, row);
        return {
          ...(await payment(company.id, row.id, old.id)),
          payroll: await dto(row),
        };
      },
    ),
  );
  for (const [action, voided] of [
    ["void", true],
    ["restore", false],
  ])
    route("POST", `/:id/payments/:paymentId/${action}`, (request) =>
      command(
        request,
        "payroll.settle",
        `payroll.payment.${action}`,
        async (company) => {
          await access(request, "wallets.transact");
          const row = await record(company.id, request.params.id),
            old = await payment(company.id, row.id, request.params.paymentId),
            body = object(request.body);
          if (body.version !== old.version) fail(409, "version_conflict");
          if (old.voided === voided)
            return { id: old.id, payroll: await dto(row) };
          const source = await db
            .prepare("SELECT * FROM journal WHERE company_id=? AND id=?")
            .get(company.id, voided ? old.journal_id : old.void_journal_id);
          if (!source) fail(422, "payroll_payment_source_missing");
          await history(
            company.id,
            "payroll_payment",
            old.id,
            old,
            request.user.id,
          );
          const entry = await postJournal(db, company, {
            scope: source.scope,
            projectId: source.project_id,
            businessDate: source.business_date,
            description: `${voided ? "Отмена" : "Восстановление"} выплаты зарплаты ${old.id}`,
            lines: JSON.parse(source.lines).map((l) => ({
              account: l.account,
              debit: l.credit,
              credit: l.debit,
            })),
          });
          await db
            .prepare(
              "INSERT INTO payroll_postings(company_id,payroll_id,journal_id,active,kind) VALUES(?,?,?,FALSE,?)",
            )
            .run(
              company.id,
              row.id,
              entry.id,
              voided ? "PAYMENT_VOID" : "PAYMENT_RESTORE",
            );
          const cash = entry.lines.find(
            (l) => l.account === `wallet:${old.wallet_id}`,
          );
          await db
            .prepare(
              "INSERT INTO wallet_entries(id,company_id,wallet_id,amount,kind,reference_id,created_at,journal_id) VALUES(?,?,?,?,?,?,?,?)",
            )
            .run(
              randomUUID(),
              company.id,
              old.wallet_id,
              cash.debit - cash.credit,
              voided ? "PAYROLL_PAYMENT_VOID" : "PAYROLL_PAYMENT_RESTORE",
              old.id,
              now(),
              entry.id,
            );
          await db
            .prepare(
              "UPDATE payroll_payments SET voided=?,void_journal_id=?,version=version+1 WHERE id=?",
            )
            .run(voided, voided ? entry.id : null, old.id);
          await projectPayments(company, row);
          return { id: old.id, payroll: await dto(row) };
        },
      ),
    );
  route("GET", "/:id/payments/:paymentId/history", async (request) => {
    const company = await access(request, "payroll.read");
    await payment(company.id, request.params.id, request.params.paymentId);
    return {
      items: await db
        .prepare(
          "SELECT h.*,u.name AS actor_name FROM entity_history h JOIN users u ON u.id=h.actor_id WHERE h.company_id=? AND h.kind='payroll_payment' AND h.entity_id=? ORDER BY revision DESC",
        )
        .all(company.id, request.params.paymentId),
    };
  });
}
