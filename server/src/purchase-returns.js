import { randomUUID } from "node:crypto";
import { businessDate, fail, integer, text } from "./security.js";
import { readSnapshot } from "./db.js";
const now = () => new Date().toISOString();
const key = (line) => JSON.stringify([line.productId, line.warehouseId]);
const round = (a, b) => Number((a + b / 2n) / b);
export const returnRows = (db, doc) =>
  db
    .prepare(
      "SELECT * FROM purchase_returns WHERE company_id=? AND document_id=? ORDER BY business_date,created_at,id",
    )
    .all(doc.company_id, doc.id);
export async function returnReductions(db, doc) {
  if (doc.kind !== "PURCHASE_GOODS") return [];
  return (await returnRows(db, doc))
    .filter((r) => r.status === "POSTED" && r.data.total > 0)
    .map((r) => ({
      id: r.id,
      amount: r.data.total,
      business_date: r.business_date,
    }));
}
// Revalue dated returns in chronological order. Cumulative rounding ensures that
// returning a whole line also reverses its last VAT minor unit. Stock cost is
// always the exact cost of the selected source layers, never a rounded average.
export async function valuePurchaseReturns(db, doc, request, editedReturnId) {
  if (doc.kind !== "PURCHASE_GOODS") return [];
  const result = [],
    cumulative = new Map(),
    cumulativeCost = new Map();
  for (const row of await returnRows(db, doc)) {
    if (row.status !== "POSTED") {
      await syncReturnMovement(db, doc, row);
      continue;
    }
    if (doc.status !== "POSTED") fail(409, "purchase_has_active_returns");
    if (row.business_date < doc.business_date)
      fail(409, "return_before_purchase");
    const lines = [];
    for (const item of row.data.lines) {
      const line = doc.data.items.find((l) => key(l) === key(item));
      if (!line) fail(409, "return_source_changed");
      const previous = cumulative.get(key(item)) ?? 0,
        next = previous + item.quantity,
        quantity = Number(line.quantity);
      if (next > quantity) fail(409, "return_exceeds_purchase");
      cumulative.set(key(item), next);
      const pending = doc.data.vatTreatment === "PENDING",
        oldCost = cumulativeCost.get(key(item)) ?? 0,
        newCost = oldCost + item.cost;
      cumulativeCost.set(key(item), newCost);
      const tax = pending
        ? round(BigInt(line.vat) * BigInt(next), BigInt(quantity)) -
          round(BigInt(line.vat) * BigInt(previous), BigInt(quantity))
        : line.total
          ? round(BigInt(line.vat) * BigInt(newCost), BigInt(line.total)) -
            round(BigInt(line.vat) * BigInt(oldCost), BigInt(line.total))
          : 0;
      lines.push({
        ...item,
        vat: tax,
        net: pending ? item.cost : item.cost - tax,
        total: pending ? item.cost + tax : item.cost,
      });
    }
    const data = {
      ...row.data,
      lines,
      cost: lines.reduce((s, l) => s + l.cost, 0),
      vat: lines.reduce((s, l) => s + l.vat, 0),
      total: lines.reduce((s, l) => s + l.total, 0),
      vatTreatment: doc.data.vatTreatment,
    };
    for (const field of ["cost", "vat", "total"]) integer(data[field], field);
    if (JSON.stringify(row.data) !== JSON.stringify(data)) {
      const automatic =
        row.data.total !== undefined && row.id !== editedReturnId;
      if (automatic) await returnSnapshot(db, row, request);
      await db
        .prepare(
          `UPDATE purchase_returns SET data=?,version=version+${automatic ? 1 : 0},updated_at=? WHERE id=?`,
        )
        .run(JSON.stringify(data), now(), row.id);
    }
    await syncReturnMovement(db, doc, { ...row, data });
    result.push({ ...row, data });
  }
  return result;
}
async function syncReturnMovement(db, doc, r) {
  // A return movement is a source projection, while entity_history retains edits.
  for (const line of r.data.lines)
    await db
      .prepare(
        "INSERT INTO movements(id,company_id,kind,data,created_at) VALUES(?,?,'PURCHASE_RETURN',?,?) ON CONFLICT(id) DO UPDATE SET data=EXCLUDED.data",
      )
      .run(
        `return:${r.id}:${key(line)}`,
        doc.company_id,
        JSON.stringify({
          documentId: doc.id,
          documentNumber: doc.number,
          returnId: r.id,
          returnNumber: r.number,
          productId: line.productId,
          warehouseId: line.warehouseId,
          productName: line.productName,
          quantity: r.status === "POSTED" ? line.quantity : 0,
          cost: r.status === "POSTED" ? line.cost : 0,
          scope: doc.scope,
          projectId: doc.project_id,
          status: r.status,
          businessDate: r.business_date,
        }),
        now(),
      );
}
async function returnSnapshot(db, row, request) {
  await db
    .prepare(
      "INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)",
    )
    .run(
      row.company_id,
      "purchase_return",
      row.id,
      JSON.stringify(row),
      request.user.id,
    );
}
export function registerPurchaseReturns(
  app,
  { db, auth, access, command, object, get, dto, projectDocument },
) {
  const base = "/v1/companies/:companyId/commercial-documents/:id/returns";
  const route = (method, suffix, handler) =>
    app.route({ method, url: base + suffix, preHandler: auth, handler });
  const source = async (company, id) => {
    const doc = await get(company.id, id);
    if (doc.kind !== "PURCHASE_GOODS") fail(409, "not_goods_purchase");
    return doc;
  };
  const getReturn = async (company, doc, id) => {
    const r = await db
      .prepare(
        "SELECT * FROM purchase_returns WHERE company_id=? AND document_id=? AND id=?",
      )
      .get(company.id, doc.id, id);
    if (!r) fail(404, "purchase_return_not_found");
    return r;
  };
  const stock = (doc) =>
    db
      .prepare(
        "SELECT s.*,b.product_id,b.warehouse_id,b.quantity,b.reserved,b.unit_cost FROM commercial_stock_layers s JOIN batches b ON b.id=s.batch_id AND b.company_id=s.company_id WHERE s.company_id=? AND s.document_id=? ORDER BY b.received_sequence",
      )
      .all(doc.company_id, doc.id);
  const restoreStock = async (row) => {
    for (const line of row.data.lines)
      for (const a of line.allocations)
        await db
          .prepare(
            "UPDATE batches SET quantity=quantity+? WHERE company_id=? AND id=?",
          )
          .run(a.quantity, row.company_id, a.batchId);
  };
  const takeStock = async (doc, items, consume = true) => {
    if (consume && doc.status !== "POSTED") fail(409, "purchase_not_posted");
    if (!Array.isArray(items) || !items.length || items.length > 200)
      fail(400, "invalid_return_lines");
    const batches = await stock(doc),
      seen = new Set(),
      lines = new Map();
    for (const item of items) {
      if (!item || typeof item !== "object" || Array.isArray(item))
        fail(400, "invalid_return_line");
      const id = text(item.batchId, "batchId"),
        q = integer(item.quantity, "quantity", 1);
      if (seen.has(id)) fail(400, "duplicate_return_batch");
      seen.add(id);
      const batch = batches.find((b) => b.batch_id === id);
      if (!batch) fail(404, "purchase_batch_not_found");
      if (consume && q > batch.quantity - batch.reserved)
        fail(409, "return_stock_unavailable");
      const original = doc.data.items.find(
        (l) =>
          l.productId === batch.product_id &&
          l.warehouseId === batch.warehouse_id,
      );
      if (!original) fail(409, "return_source_changed");
      const k = key(original),
        line = lines.get(k) ?? {
          productId: original.productId,
          warehouseId: original.warehouseId,
          productName: original.productName,
          warehouseName: original.warehouseName,
          quantity: 0,
          cost: 0,
          allocations: [],
        };
      const cost = q * batch.unit_cost;
      integer(cost, "cost");
      line.quantity += q;
      if (line.quantity > Number(original.quantity))
        fail(409, "return_exceeds_purchase");
      line.cost += cost;
      line.allocations.push({
        batchId: id,
        quantity: q,
        unitCost: batch.unit_cost,
      });
      lines.set(k, line);
      if (consume)
        await db
          .prepare(
            "UPDATE batches SET quantity=quantity-? WHERE company_id=? AND id=?",
          )
          .run(q, doc.company_id, id);
    }
    return [...lines.values()];
  };
  const finish = async (company, doc, request, id) => {
    await db
      .prepare(
        "INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)",
      )
      .run(
        company.id,
        "commercial_document",
        doc.id,
        JSON.stringify(doc),
        request.user.id,
      );
    await projectDocument(company, doc, request, { editedReturnId: id });
    await db
      .prepare(
        "UPDATE commercial_documents SET version=version+1,updated_at=? WHERE id=?",
      )
      .run(now(), doc.id);
    const r = await getReturn(company, doc, id);
    return { item: r, document: await dto(await get(company.id, doc.id)) };
  };
  route("GET", "", (request) =>
    readSnapshot(db, async () => {
      const company = await access(request, "documents.read");
      await access(request, "inventory.read");
      const doc = await source(company, request.params.id);
      return {
        items: await returnRows(db, doc),
        batches: (await stock(doc)).map((b) => ({
          ...b,
          source_quantity: Number(
            doc.data.items.find(
              (l) =>
                l.productId === b.product_id &&
                l.warehouseId === b.warehouse_id,
            )?.quantity ?? b.original_quantity,
          ),
          product_name: doc.data.items.find(
            (l) =>
              l.productId === b.product_id && l.warehouseId === b.warehouse_id,
          )?.productName,
          warehouse_name: doc.data.items.find(
            (l) =>
              l.productId === b.product_id && l.warehouseId === b.warehouse_id,
          )?.warehouseName,
        })),
        businessDate: businessDate(undefined, company.timezone),
      };
    }),
  );
  route("GET", "/:returnId/export-data", (request) =>
    readSnapshot(db, async () => {
      const company = await access(request, "documents.export");
      await access(request, "inventory.read");
      const doc = await source(company, request.params.id);
      return {
        item: await getReturn(company, doc, request.params.returnId),
        source: doc,
      };
    }),
  );
  route("GET", "/:returnId/history", async (request) => {
    const company = await access(request, "documents.read"),
      doc = await source(company, request.params.id);
    await getReturn(company, doc, request.params.returnId);
    return {
      items: await db
        .prepare(
          "SELECT h.*,u.name AS actor_name FROM entity_history h JOIN users u ON u.id=h.actor_id WHERE h.company_id=? AND h.kind='purchase_return' AND h.entity_id=? ORDER BY revision DESC LIMIT 200",
        )
        .all(company.id, request.params.returnId),
    };
  });
  route("POST", "", (request) =>
    command(
      request,
      "documents.post",
      "purchase.return.create",
      async (company) => {
        await access(request, "inventory.writeoff");
        const doc = await source(company, request.params.id),
          body = object(request.body);
        if (body.documentVersion !== doc.version) fail(409, "version_conflict");
        const date = businessDate(body.businessDate, company.timezone),
          reason = text(body.reason, "reason", 2000);
        if (date < doc.business_date) fail(409, "return_before_purchase");
        const lines = await takeStock(doc, body.lines),
          id = randomUUID(),
          year = Number(date.slice(0, 4));
        await db
          .prepare(
            "INSERT INTO document_sequences VALUES(?,?,?,1) ON CONFLICT DO NOTHING",
          )
          .run(company.id, "PURCHASE_RETURN", year);
        const n = await db
          .prepare(
            "UPDATE document_sequences SET next_number=next_number+1 WHERE company_id=? AND kind=? AND year=? RETURNING next_number-1 AS number",
          )
          .get(company.id, "PURCHASE_RETURN", year);
        await db
          .prepare(
            "INSERT INTO purchase_returns(id,company_id,document_id,number,status,business_date,reason,data,author_id,created_at,updated_at) VALUES(?,?,?,?,'POSTED',?,?,?,?,?,?)",
          )
          .run(
            id,
            company.id,
            doc.id,
            `ВП-${year}-${String(n.number).padStart(6, "0")}`,
            date,
            reason,
            JSON.stringify({ lines }),
            request.user.id,
            now(),
            now(),
          );
        return finish(company, doc, request, id);
      },
    ),
  );
  route("PUT", "/:returnId", (request) =>
    command(
      request,
      "documents.post",
      "purchase.return.update",
      async (company) => {
        await access(request, "inventory.writeoff");
        const doc = await source(company, request.params.id),
          old = await getReturn(company, doc, request.params.returnId),
          body = object(request.body);
        if (
          body.version !== old.version ||
          body.documentVersion !== doc.version
        )
          fail(409, "version_conflict");
        const date = businessDate(
            body.businessDate ?? old.business_date,
            company.timezone,
          ),
          reason = text(body.reason ?? old.reason, "reason", 2000);
        if (date < doc.business_date) fail(409, "return_before_purchase");
        await returnSnapshot(db, old, request);
        let lines = old.data.lines;
        if (old.status === "POSTED") {
          await restoreStock(old);
          lines = await takeStock(
            doc,
            body.lines ?? old.data.lines.flatMap((l) => l.allocations),
          );
        } else if (body.lines !== undefined)
          lines = await takeStock(doc, body.lines, false);
        let nextData = { ...old.data, lines };
        if (old.status === "CANCELLED" && body.lines !== undefined) {
          lines = lines.map((item) => {
            const line = doc.data.items.find((l) => key(l) === key(item));
            if (!line) fail(409, "return_source_changed");
            const pending = doc.data.vatTreatment === "PENDING";
            const vat = pending
              ? round(
                  BigInt(line.vat) * BigInt(item.quantity),
                  BigInt(Number(line.quantity)),
                )
              : line.total
                ? round(
                    BigInt(line.vat) * BigInt(item.cost),
                    BigInt(line.total),
                  )
                : 0;
            return {
              ...item,
              vat,
              net: pending ? item.cost : item.cost - vat,
              total: pending ? item.cost + vat : item.cost,
            };
          });
          nextData = {
            ...nextData,
            lines,
            cost: lines.reduce((s, l) => s + l.cost, 0),
            vat: lines.reduce((s, l) => s + l.vat, 0),
            total: lines.reduce((s, l) => s + l.total, 0),
            vatTreatment: doc.data.vatTreatment,
          };
          for (const f of ["cost", "vat", "total"]) integer(nextData[f], f);
        }
        // Clear obsolete movement projections when the edited selection changes.
        await db
          .prepare(
            'UPDATE movements SET data=(data::jsonb || \'{"quantity":0,"cost":0,"status":"CANCELLED"}\'::jsonb)::text WHERE company_id=? AND data::jsonb->>\'returnId\'=?',
          )
          .run(company.id, old.id);
        await db
          .prepare(
            "UPDATE purchase_returns SET data=?,business_date=?,reason=?,version=version+1,updated_at=? WHERE id=?",
          )
          .run(JSON.stringify(nextData), date, reason, now(), old.id);
        return finish(company, doc, request, old.id);
      },
    ),
  );
  for (const [action, status] of [
    ["cancel", "CANCELLED"],
    ["restore", "POSTED"],
  ])
    route("POST", `/:returnId/${action}`, (request) =>
      command(
        request,
        "documents.post",
        `purchase.return.${action}`,
        async (company) => {
          await access(request, "inventory.writeoff");
          const doc = await source(company, request.params.id),
            old = await getReturn(company, doc, request.params.returnId),
            body = object(request.body);
          if (
            body.version !== old.version ||
            body.documentVersion !== doc.version
          )
            fail(409, "version_conflict");
          if (old.status === status)
            return { item: old, document: await dto(doc) };
          await returnSnapshot(db, old, request);
          if (status === "CANCELLED") await restoreStock(old);
          else {
            const lines = await takeStock(
              doc,
              old.data.lines.flatMap((l) => l.allocations),
            );
            await db
              .prepare("UPDATE purchase_returns SET data=? WHERE id=?")
              .run(JSON.stringify({ ...old.data, lines }), old.id);
          }
          await db
            .prepare(
              "UPDATE purchase_returns SET status=?,version=version+1,updated_at=? WHERE id=?",
            )
            .run(status, now(), old.id);
          return finish(company, doc, request, old.id);
        },
      ),
    );
}
