import { accountReference } from "./legal.js";
import { readSnapshot } from "./db.js";
import { fail, businessDate } from "./security.js";
import { projectReference } from "./accounting.js";
const money = (raw) => {
  const n = BigInt(raw ?? 0);
  if (
    n > BigInt(Number.MAX_SAFE_INTEGER) ||
    n < BigInt(Number.MIN_SAFE_INTEGER)
  )
    fail(422, "report_amount_overflow");
  return Number(n);
};
// Internal operational categories from the researched 2026 reference, not an
// approved posting policy or a statutory balance sheet. Reserve1090 is not cash.
const reference = accountReference("2026-01-01");
const cashAccounts = [
  "cash",
  "1010",
  "1020",
  "1030",
  "1040",
  "1050",
  "1060",
  "1070",
  "1080",
];
const groups = {
  receivables: ["receivables", "1210", "2110"],
  payables: ["payables", "3310", "4110"],
  customer_advances: ["customer_advances", "3510", "4410"],
  supplier_advances: ["supplier_advances", "1710", "2910"],
};
const allAccounts = [...cashAccounts, ...Object.values(groups).flat()];
for (const code of allAccounts.filter((code) => /^\d{4}$/.test(code)))
  if (!reference.accounts.some((a) => a.code === code && !a.group))
    throw Error("Missing researched operational account");
const literals = (items) => items.map((code) => `'${code}'`).join(",");
const cashFilter = `(l.account LIKE 'wallet:%' OR l.account IN (${literals(cashAccounts)}))`;
export function registerDashboard(app, { db, auth, access }) {
  app.get(
    "/v1/companies/:companyId/dashboard",
    { preHandler: auth },
    (request) =>
      readSnapshot(db, async () => {
        const company = await access(request, "reports.read");
        const today = businessDate(undefined, company.timezone);
        await access(request, "accounting.read");
        await access(request, "wallets.read");
        const membership = await db
            .prepare(
              "SELECT role,permissions FROM memberships WHERE company_id=? AND user_id=?",
            )
            .get(company.id, request.user.id),
          permissions = new Set(JSON.parse(membership.permissions));
        const can = (...required) =>
          membership.role === "owner" ||
          required.every((p) => permissions.has(p));
        const project = request.query.projectId;
        if (project !== undefined && project !== "unassigned")
          await projectReference(db, company.id, project);
        const scope = request.query.scope ?? "ACCOUNTING";
        if (!["ACCOUNTING", "MANAGEMENT"].includes(scope))
          fail(400, "invalid_report_scope");
        const selected =
          project === undefined
            ? []
            : [project === "unassigned" ? null : project];
        const projectFilter =
          project === undefined
            ? ""
            : " AND j.project_id IS NOT DISTINCT FROM ?";
        const journalFilter = `j.company_id=? AND j.scope IN (?,'BOTH')${projectFilter} AND j.business_date<=?`;
        const journalArgs = [company.id, scope, ...selected, today];
        const accounts = await db
          .prepare(
            `SELECT l.account,sum(l.debit-l.credit)::text AS balance FROM journal j JOIN journal_lines l ON l.entry_id=j.id WHERE ${journalFilter} AND (l.account LIKE 'wallet:%' OR l.account IN (${literals(allAccounts)})) GROUP BY l.account`,
          )
          .all(...journalArgs);
        const balance = (account) =>
          accounts
            .filter((a) => groups[account].includes(a.account))
            .reduce((sum, a) => sum + BigInt(a.balance), 0n);
        let cash = 0n;
        for (const a of accounts)
          if (
            a.account.startsWith("wallet:") ||
            cashAccounts.includes(a.account)
          )
            cash += BigInt(a.balance);
        const charts = await db
          .prepare(
            `WITH months AS(SELECT generate_series(date_trunc('month',?::date)-interval '5 months',date_trunc('month',?::date),interval '1 month')::date AS month),
   cash_entries AS(SELECT j.business_date,sum(l.debit-l.credit) AS change FROM journal j JOIN journal_lines l ON l.entry_id=j.id WHERE ${journalFilter} AND ${cashFilter} GROUP BY j.business_date)
   SELECT to_char(m.month,'YYYY-MM') AS month,
   COALESCE((SELECT sum(e.change) FROM cash_entries e WHERE e.business_date<m.month),0)::text AS opening,
   COALESCE((SELECT sum(e.change) FROM cash_entries e WHERE e.business_date<(m.month+interval '1 month')),0)::text AS closing FROM months m ORDER BY m.month`,
          )
          .all(today, today, ...journalArgs);
        const recent = [],
          tasks = [];
        const sourceFilter =
          project === undefined ? "" : " AND project_id IS NOT DISTINCT FROM ?";
        if (can("documents.read")) {
          const docs = await db
            .prepare(
              `SELECT id,kind,number,status,business_date,created_at,data->'counterparty'->>'name' AS counterparty,(data->>'total')::text AS total FROM commercial_documents WHERE company_id=? AND scope IN (?,'BOTH')${sourceFilter} ORDER BY business_date DESC,created_at DESC,id DESC LIMIT 5`,
            )
            .all(company.id, scope, ...selected);
          recent.push(
            ...docs.map((d) => ({
              ...d,
              sourceKind: "SERVICE",
              total: money(d.total),
            })),
          );
          const drafts = await db
            .prepare(
              `SELECT id,kind,number FROM commercial_documents WHERE company_id=? AND scope IN (?,'BOTH')${sourceFilter} AND status='DRAFT' ORDER BY updated_at DESC,id DESC LIMIT 1`,
            )
            .get(company.id, scope, ...selected);
          if (drafts)
            tasks.push({
              kind: "DOCUMENT_DRAFT",
              id: drafts.id,
              title: `Завершить ${drafts.kind === "SALE_INVOICE" ? "счёт" : drafts.kind === "SALE_ACT" ? "акт" : "поступление"} № ${drafts.number}`,
              description: "Черновик ещё не проведён",
              sourceKind: "SERVICE",
            });
        }
        if (can("orders.read", "catalog.read")) {
          const goods = await db
            .prepare(
              `SELECT id,status,created_at,data::jsonb AS data FROM orders WHERE company_id=? AND data::jsonb->>'scope' IN (?,'BOTH')${project === undefined ? "" : " AND data::jsonb->>'projectId' IS NOT DISTINCT FROM ?"} ORDER BY data::jsonb->>'businessDate' DESC,created_at DESC,id DESC LIMIT 5`,
            )
            .all(company.id, scope, ...selected);
          recent.push(
            ...goods.map((g) => ({
              id: g.id,
              kind: "GOODS",
              sourceKind: "GOODS",
              number: g.data.number ?? g.id,
              status: g.status,
              business_date: g.data.businessDate,
              created_at: g.created_at,
              counterparty: g.data.counterparty?.name ?? "",
              total: money(g.data.total),
            })),
          );
        }
        if (can("bank.read")) {
          const pending = await db
            .prepare(
              `SELECT count(*)::text AS count FROM bank_import_rows r JOIN wallets w ON w.id=r.wallet_id AND w.company_id=r.company_id WHERE r.company_id=? AND w.scope IN (?,'BOTH') AND r.journal_id IS NULL AND r.classification IS DISTINCT FROM 'IGNORE'`,
            )
            .get(company.id, scope);
          if (Number(pending.count) > 0)
            tasks.unshift({
              kind: "BANK_REVIEW",
              count: Number(pending.count),
              title: `Проверить операции: ${pending.count}`,
              description:
                "Строки выписки ещё не сопоставлены. Задача относится ко всей фирме.",
            });
        }
        if (can("tax-calendar.read")) {
          const due = await db
            .prepare(
              "SELECT id,title,due_date FROM tax_calendar_tasks WHERE company_id=? AND status='OPEN' AND due_date<=? ORDER BY due_date,id LIMIT 1",
            )
            .get(company.id, today);
          if (due)
            tasks.push({
              kind: "TAX_TASK",
              id: due.id,
              title: due.title,
              description: `Подтверждённый срок: ${due.due_date} · общая задача фирмы`,
            });
        }
        recent.sort(
          (a, b) =>
            b.business_date.localeCompare(a.business_date) ||
            b.created_at.localeCompare(a.created_at) ||
            b.id.localeCompare(a.id),
        );
        const actor = await db
          .prepare("SELECT name FROM users WHERE id=?")
          .get(request.user.id);
        return {
          scope,
          projectId: project ?? null,
          companyBusinessDate: today,
          userName: actor?.name ?? "",
          money: {
            cash: money(cash),
            receivables: money(
              balance("receivables") > 0n ? balance("receivables") : 0n,
            ),
            payables: money(
              balance("payables") < 0n ? -balance("payables") : 0n,
            ),
            customerAdvances: money(-balance("customer_advances")),
            supplierAdvances: money(balance("supplier_advances")),
          },
          chartBasis: "MONTH_END_CASH_BALANCE",
          chart: charts.map((x) => ({
            month: x.month,
            opening: money(x.opening),
            closing: money(x.closing),
          })),
          recentDocuments: recent.slice(0, 5),
          tasks,
          snapshotAt: new Date().toISOString(),
          coverage: "OPERATIONAL_CASH_CUSTOMER_SUPPLIER_BALANCES",
          numericReferenceVersion: reference.version,
        };
      }),
  );
}
