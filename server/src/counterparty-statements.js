import { fail, text, businessDate, scope } from "./security.js";
import { projectReference } from "./accounting.js";
import { readSnapshot } from "./db.js";

const amount = (raw) => {
  const n = BigInt(raw ?? 0);
  if (
    n > BigInt(Number.MAX_SAFE_INTEGER) ||
    n < BigInt(Number.MIN_SAFE_INTEGER)
  )
    fail(422, "report_amount_overflow");
  return Number(n);
};
export function registerCounterpartyStatements(
  app,
  { db, auth, access, pageLimit },
) {
  app.get(
    "/v1/companies/:companyId/counterparties/:kind/:id/statement",
    { preHandler: auth },
    (request) =>
      readSnapshot(db, async () => {
        const company = await access(request, "catalog.read");
        for (const permission of [
          "accounting.read",
          "documents.read",
          "orders.read",
          "debts.read",
          "assets.read",
        ])
          await access(request, permission);
        const kind = request.params.kind;
        if (!["clients", "suppliers"].includes(kind))
          fail(400, "invalid_counterparty_kind");
        const party = await db
          .prepare(
            "SELECT * FROM documents WHERE company_id=? AND kind=? AND id=?",
          )
          .get(company.id, kind, text(request.params.id, "counterpartyId"));
        if (!party) fail(404, "counterparty_not_found");
        const from = businessDate(request.query.from ?? "0001-01-01"),
          to = businessDate(request.query.to ?? "9999-12-31");
        if (from > to) fail(400, "invalid_date_range");
        const ledgerScope = scope(request.query.scope ?? "ACCOUNTING");
        if (ledgerScope === "BOTH") fail(400, "invalid_report_scope");
        const selected = request.query.projectId;
        if (selected !== undefined && selected !== "unassigned")
          await projectReference(db, company.id, selected);
        let afterDate = "0001-01-01",
          afterId = "";
        if (request.query.after !== undefined) {
          try {
            const cursor = JSON.parse(
              Buffer.from(
                text(request.query.after, "after", 300),
                "base64url",
              ).toString(),
            );
            afterDate = businessDate(cursor.date);
            afterId = text(cursor.id, "after", 100);
          } catch {
            fail(400, "invalid_cursor");
          }
        }
        const cte = `WITH docs AS(SELECT * FROM commercial_documents WHERE company_id=? AND data->>'counterpartyId'=? AND ${kind === "clients" ? "kind IN ('SALE_INVOICE','SALE_ACT')" : "kind='PURCHASE_ACT'"}),
   goods AS(SELECT id,company_id FROM orders WHERE company_id=? AND data::jsonb->>'counterpartyId'=? AND ?='clients'),
   opening_debts AS(SELECT id,company_id FROM debts WHERE company_id=? AND counterparty_id=? AND type=?),
   assets AS(SELECT id,company_id FROM fixed_assets WHERE company_id=? AND supplier_id=? AND ?='suppliers'),
   service_sources AS(
    SELECT p.journal_id,d.id AS source_id FROM commercial_postings p JOIN docs d ON d.id=p.document_id AND d.company_id=p.company_id
    UNION SELECT p.journal_id,d.id FROM commercial_payments p JOIN commercial_documents original ON original.id=p.document_id AND original.company_id=p.company_id LEFT JOIN commercial_documents child ON child.source_invoice_id=original.id AND child.company_id=original.company_id AND child.status='POSTED' JOIN docs d ON d.id=COALESCE(child.id,original.id)
    UNION SELECT e.journal_id,d.id FROM commercial_payments p JOIN commercial_documents original ON original.id=p.document_id AND original.company_id=p.company_id LEFT JOIN commercial_documents child ON child.source_invoice_id=original.id AND child.company_id=original.company_id AND child.status='POSTED' JOIN docs d ON d.id=COALESCE(child.id,original.id) JOIN wallet_entries e ON e.company_id=p.company_id AND e.reference_id=p.id WHERE e.journal_id IS NOT NULL
   ),goods_sources AS(
    SELECT p.journal_id,g.id AS source_id FROM order_postings p JOIN goods g ON g.id=p.order_id AND g.company_id=p.company_id
    UNION SELECT p.journal_id,g.id FROM payments p JOIN goods g ON g.id=p.order_id AND g.company_id=p.company_id
    UNION SELECT p.void_journal_id,g.id FROM payments p JOIN goods g ON g.id=p.order_id AND g.company_id=p.company_id
    UNION SELECT p.journal_id,g.id FROM order_settlement_postings p JOIN goods g ON g.id=p.order_id AND g.company_id=p.company_id
    UNION SELECT e.journal_id,g.id FROM payments p JOIN goods g ON g.id=p.order_id AND g.company_id=p.company_id JOIN wallet_entries e ON e.company_id=p.company_id AND e.reference_id=p.id
   ),sources AS(
    SELECT journal_id,source_id,'SERVICE' AS source_kind FROM service_sources
    UNION SELECT journal_id,source_id,'GOODS' FROM goods_sources
    UNION SELECT p.journal_id,d.id,'DEBT' FROM debt_postings p JOIN opening_debts d ON d.id=p.debt_id AND d.company_id=p.company_id
    UNION SELECT p.journal_id,a.id,'ASSET' FROM asset_postings p JOIN assets a ON a.id=p.asset_id AND a.company_id=p.company_id
   ),filtered AS(SELECT DISTINCT j.* FROM journal j JOIN sources s ON s.journal_id=j.id WHERE j.company_id=? AND j.scope IN (?,'BOTH')${selected === undefined ? "" : " AND j.project_id IS NOT DISTINCT FROM ?"})`;
        const args = [
          company.id,
          party.id,
          company.id,
          party.id,
          kind,
          company.id,
          party.id,
          kind === "clients" ? "AR" : "AP",
          company.id,
          party.id,
          kind,
          company.id,
          ledgerScope,
          ...(selected === undefined
            ? []
            : [selected === "unassigned" ? null : selected]),
        ];
        const accountNames =
          kind === "clients"
            ? ["receivables", "customer_advances"]
            : ["payables", "supplier_advances"];
        const balances = await db
          .prepare(
            `${cte} SELECT l.account,
   COALESCE(sum(l.debit-l.credit) FILTER(WHERE j.business_date<?),0)::text AS opening,
   COALESCE(sum(l.debit) FILTER(WHERE j.business_date>=?),0)::text AS debit,
   COALESCE(sum(l.credit) FILTER(WHERE j.business_date>=?),0)::text AS credit,
   COALESCE(sum(l.debit-l.credit),0)::text AS closing
   FROM filtered j JOIN journal_lines l ON l.entry_id=j.id WHERE j.business_date<=? AND l.account IN (?,?) GROUP BY l.account`,
          )
          .all(...args, from, from, from, to, ...accountNames);
        const limit = pageLimit(request.query);
        const rows = await db
          .prepare(
            `${cte} SELECT j.id,j.business_date,j.description,j.project_id,
   (SELECT s.source_kind FROM sources s WHERE s.journal_id=j.id ORDER BY s.source_kind,s.source_id LIMIT 1) AS source_kind,
   (SELECT s.source_id FROM sources s WHERE s.journal_id=j.id ORDER BY s.source_kind,s.source_id LIMIT 1) AS source_id,
   COALESCE((SELECT jsonb_agg(jsonb_build_object('account',l.account,'debit',l.debit,'credit',l.credit) ORDER BY l.position) FROM journal_lines l WHERE l.entry_id=j.id AND l.account IN (?,?)),'[]'::jsonb) AS lines
   FROM filtered j WHERE j.business_date>=? AND j.business_date<=? AND (j.business_date,j.id)>(?::date,?) AND EXISTS(SELECT 1 FROM journal_lines l WHERE l.entry_id=j.id AND l.account IN (?,?)) ORDER BY j.business_date,j.id LIMIT ?`,
          )
          .all(
            ...args,
            ...accountNames,
            from,
            to,
            afterDate,
            afterId,
            ...accountNames,
            limit,
          );
        const accounts = accountNames.map((account) => {
          const raw = balances.find((b) => b.account === account) ?? {};
          return {
            account,
            ...Object.fromEntries(
              ["opening", "debit", "credit", "closing"].map((k) => [
                k,
                amount(raw[k]),
              ]),
            ),
          };
        });
        return {
          counterparty: { ...party, data: JSON.parse(party.data) },
          scope: ledgerScope,
          from,
          to,
          accounts,
          items: rows,
          includedSources: ["SERVICE", "GOODS", "DEBT", "ASSET"],
          snapshotAt: new Date().toISOString(),
          coverage: "LINKED_JOURNAL_ONLY",
          nextCursor:
            rows.length === limit
              ? Buffer.from(
                  JSON.stringify({
                    date: rows.at(-1).business_date,
                    id: rows.at(-1).id,
                  }),
                ).toString("base64url")
              : null,
        };
      }),
  );
}
