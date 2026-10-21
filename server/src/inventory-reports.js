import { readSnapshot } from "./db.js";
import { fail, scope, text, businessDate } from "./security.js";

// PostgreSQL sums remain NUMERIC until the API range check, including quantities.
const safe = (raw) => {
  const n = BigInt(raw);
  if (n < 0n || n > BigInt(Number.MAX_SAFE_INTEGER))
    fail(422, "report_amount_overflow");
  return Number(n);
};
const csvCell = (raw) => {
  const value = String(raw ?? "");
  return (
    '"' +
    (/^(?:\s*[=+\-@]|[\t\r\n])/u.test(value) ? "'" : "") +
    value.replaceAll('"', '""') +
    '"'
  );
};
const decimal = (minor) =>
  `${BigInt(minor) / 100n},${String(BigInt(minor) % 100n).padStart(2, "0")}`;

export function registerInventoryReports(app, { db, auth, access, pageLimit }) {
  app.get(
    "/v1/companies/:companyId/inventory/operations",
    { preHandler: auth },
    (request) =>
      readSnapshot(db, async () => {
        const company = await access(request, "inventory.read");
        const ledgerScope = scope(request.query.scope ?? "ACCOUNTING");
        const from = businessDate(request.query.from ?? "0001-01-01"),
          to = businessDate(request.query.to ?? "9999-12-31");
        if (from > to) fail(400, "invalid_date_range");
        const warehouseId = request.query.warehouseId,
          productId = request.query.productId;
        const type = request.query.type;
        if (
          type !== undefined &&
          !["RECEIPT", "TRANSFER", "WRITEOFF", "PURCHASE_RETURN"].includes(type)
        )
          fail(400, "invalid_stock_operation");
        const filters = `m.company_id=? AND m.data::jsonb->>'scope'=?
      AND COALESCE(m.data::jsonb->>'businessDate',substring(m.created_at,1,10)) BETWEEN ? AND ?
      ${warehouseId === undefined ? "" : "AND (m.data::jsonb->>'warehouseId'=? OR m.data::jsonb->>'sourceWarehouseId'=? OR m.data::jsonb->>'targetWarehouseId'=?)"}
      ${productId === undefined ? "" : "AND m.data::jsonb->>'productId'=?"}
      ${type === undefined ? "" : "AND m.kind=?"}`;
        const params = [
          company.id,
          ledgerScope,
          from,
          to,
          ...(warehouseId === undefined
            ? []
            : [text(warehouseId, "warehouseId"), warehouseId, warehouseId]),
          ...(productId === undefined ? [] : [text(productId, "productId")]),
          ...(type === undefined ? [] : [type]),
        ];
        const limit = pageLimit(request.query);
        let boundary;
        if (request.query.after !== undefined) {
          boundary = await db
            .prepare(
              `SELECT m.created_at,m.id FROM movements m WHERE ${filters} AND m.id=?`,
            )
            .get(...params, text(request.query.after, "after"));
          if (!boundary) fail(400, "invalid_cursor");
        }
        const rows = await db
          .prepare(
            `SELECT m.*,p.data::jsonb->>'name' AS product_name
      FROM movements m LEFT JOIN documents p ON p.company_id=m.company_id AND p.kind='nomenklatura' AND p.id=m.data::jsonb->>'productId'
      WHERE ${filters} ${boundary ? "AND (m.created_at,m.id)<(?,?)" : ""}
      ORDER BY m.created_at DESC,m.id DESC LIMIT ?`,
          )
          .all(
            ...params,
            ...(boundary ? [boundary.created_at, boundary.id] : []),
            limit,
          );
        return {
          items: rows.map((r) => ({ ...r, data: JSON.parse(r.data) })),
          nextCursor: rows.length === limit ? rows.at(-1).id : null,
          coverage: "RECORDED_OPERATIONS_ONLY",
          note: "Поступления, записанные до появления журнала операций, и товарные отгрузки здесь не включены. Отгрузки находятся в товарных продажах.",
        };
      }),
  );
  app.get(
    "/v1/companies/:companyId/inventory/balances",
    { preHandler: auth },
    (request) =>
      readSnapshot(db, async () => {
        const company = await access(request, "inventory.read");
        const ledgerScope = scope(request.query.scope ?? "ACCOUNTING");
        const warehouseId = request.query.warehouseId,
          productId = request.query.productId;
        for (const [kind, id] of [
          ["warehouses", warehouseId],
          ["nomenklatura", productId],
        ]) {
          if (
            id !== undefined &&
            !(await db
              .prepare(
                "SELECT 1 FROM documents WHERE company_id=? AND kind=? AND id=?",
              )
              .get(company.id, kind, text(id, "referenceId")))
          )
            fail(404, "catalog_reference_not_found");
        }
        const query = request.query.q ?? "";
        if (typeof query !== "string" || query.length > 200)
          fail(400, "invalid_search");
        const availability = request.query.availability ?? "ALL";
        if (
          !["ALL", "AVAILABLE", "RESERVED", "EMPTY", "LOW"].includes(
            availability,
          )
        )
          fail(400, "invalid_stock_filter");
        const pattern = `%${query.trim().replace(/[\\%_]/g, (c) => "\\" + c)}%`;
        // A selected warehouse includes catalog goods with no batches yet. Across
        // warehouses, only real batch positions are listed; no Cartesian fake stock.
        const cte = `WITH stock AS (
      SELECT product_id,warehouse_id,sum(quantity)::text AS quantity,
        sum(reserved)::text AS reserved,sum(quantity*unit_cost)::text AS value,
        sum((quantity-reserved)*unit_cost)::text AS available_value,count(*) AS batch_count
      FROM batches WHERE company_id=? AND scope=? ${warehouseId === undefined ? "" : "AND warehouse_id=?"}
      GROUP BY product_id,warehouse_id
    ), positions AS (
      SELECT p.id AS product_id,${warehouseId === undefined ? "s.warehouse_id" : "?::text"} AS warehouse_id,
        COALESCE(p.data::jsonb->>'name',p.id) AS product_name,
        COALESCE(p.data::jsonb->>'unit','ед.') AS unit,
        CASE WHEN jsonb_typeof(p.data::jsonb->'minimumStock')='number' AND p.data::jsonb->>'minimumStock' ~ '^[0-9]{1,13}$' THEN (p.data::jsonb->>'minimumStock')::numeric ELSE NULL END AS minimum_stock,
        COALESCE(w.data::jsonb->>'name',${warehouseId === undefined ? "s.warehouse_id" : "?::text"}) AS warehouse_name,
        COALESCE(s.quantity,'0')::numeric AS quantity,COALESCE(s.reserved,'0')::numeric AS reserved,
        COALESCE(s.value,'0')::numeric AS value,COALESCE(s.available_value,'0')::numeric AS available_value,
        COALESCE(s.batch_count,0) AS batch_count
      FROM documents p ${warehouseId === undefined ? "JOIN" : "LEFT JOIN"} stock s ON s.product_id=p.id
      LEFT JOIN documents w ON w.company_id=p.company_id AND w.kind='warehouses' AND w.id=${warehouseId === undefined ? "s.warehouse_id" : "?"}
      WHERE p.company_id=? AND p.kind='nomenklatura' ${productId === undefined ? "" : "AND p.id=?"}
    ), filtered AS (
      SELECT *,quantity-reserved AS available FROM positions
      WHERE (product_name ILIKE ? OR warehouse_name ILIKE ?)
      ${availability === "AVAILABLE" ? "AND quantity>reserved" : availability === "RESERVED" ? "AND reserved>0" : availability === "EMPTY" ? "AND quantity=0" : availability === "LOW" ? "AND quantity-reserved<minimum_stock" : ""}
    )`;
        const params = [
          company.id,
          ledgerScope,
          ...(warehouseId === undefined
            ? []
            : [warehouseId, warehouseId, warehouseId, warehouseId]),
          company.id,
          ...(productId === undefined ? [] : [productId]),
          pattern,
          pattern,
        ];
        const totals = await db
          .prepare(
            `${cte} SELECT count(*) AS positions,count(DISTINCT product_id) AS products,
      count(*) FILTER(WHERE quantity=0) AS empty,count(*) FILTER(WHERE quantity-reserved<minimum_stock) AS low,
      count(*) FILTER(WHERE minimum_stock IS NOT NULL) AS configured_minimums,count(*) FILTER(WHERE reserved>0) AS reserved_positions,
      COALESCE(sum(value),0)::text AS value,COALESCE(sum(available_value),0)::text AS available_value FROM filtered`,
          )
          .get(...params);
        const summary = {
          ...totals,
          value: safe(totals.value),
          available_value: safe(totals.available_value),
        };
        const exporting = request.query.export === "csv";
        if (request.query.export !== undefined && !exporting)
          fail(400, "invalid_export_format");
        if (exporting && totals.positions > 10000)
          fail(422, "stock_export_too_large");
        const cursor = request.query.after ?? "";
        if (typeof cursor !== "string" || cursor.length > 1000)
          fail(400, "invalid_cursor");
        const limit = exporting ? 10001 : pageLimit(request.query);
        const rows = await db
          .prepare(
            `${cte} SELECT product_id,warehouse_id,product_name,warehouse_name,unit,batch_count,minimum_stock,
      quantity::text,reserved::text,available::text,value::text,available_value::text,
      product_id||':'||warehouse_id AS cursor FROM filtered
      WHERE product_id||':'||warehouse_id>? ORDER BY product_id,warehouse_id LIMIT ?`,
          )
          .all(...params, exporting ? "" : cursor, limit);
        const items = rows.map((r) => ({
          ...r,
          quantity: safe(r.quantity),
          reserved: safe(r.reserved),
          available: safe(r.available),
          value: safe(r.value),
          available_value: safe(r.available_value),
        }));
        const snapshotAt = new Date().toISOString();
        if (exporting) {
          const lines = [
            [
              "Товар",
              "Склад",
              "Контур",
              "Единица",
              "В наличии",
              "Резерв",
              "Доступно",
              "Минимум доступного остатка",
              `Стоимость ${company.currency}`,
              `Доступная стоимость ${company.currency}`,
            ],
            ...items.map((r) => [
              r.product_name,
              r.warehouse_name,
              ledgerScope,
              r.unit,
              r.quantity,
              r.reserved,
              r.available,
              r.minimum_stock ?? "",
              decimal(r.value),
              decimal(r.available_value),
            ]),
          ];
          return {
            snapshotAt,
            scope: ledgerScope,
            summary,
            rowCount: items.length,
            csv:
              "\uFEFF" +
              lines.map((row) => row.map(csvCell).join(";")).join("\r\n"),
          };
        }
        return {
          snapshotAt,
          businessDate: businessDate(undefined, company.timezone),
          scope: ledgerScope,
          summary,
          items,
          nextCursor: rows.length === limit ? rows.at(-1).cursor : null,
        };
      }),
  );
}
