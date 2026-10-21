import { randomUUID } from "node:crypto";
import { fail, integer, text } from "./security.js";
export const isPurchaseKind = (kind) =>
  ["PURCHASE_ACT", "PURCHASE_GOODS"].includes(kind);
const lineKey = (line) => JSON.stringify([line.productId, line.warehouseId]);

export async function purchaseItems(db, companyId, items, previous) {
  if (!Array.isArray(items) || !items.length || items.length > 100)
    fail(400, "invalid_items");
  const result = [],
    seen = new Set();
  for (const item of items) {
    if (!item || typeof item !== "object" || Array.isArray(item))
      fail(400, "invalid_item");
    if (item.description !== undefined && typeof item.description !== "string")
      fail(400, "invalid_description");
    const productId = text(item.productId, "productId"),
      warehouseId = text(item.warehouseId, "warehouseId");
    if (
      typeof item.quantity !== "string" ||
      !/^[1-9][0-9]{0,8}$/.test(item.quantity)
    )
      fail(400, "invalid_goods_quantity");
    const key = lineKey({ productId, warehouseId });
    if (seen.has(key)) fail(400, "duplicate_purchase_position");
    seen.add(key);
    const old = previous?.data.items.find(
      (l) => l.productId === productId && l.warehouseId === warehouseId,
    );
    const product = await db
      .prepare(
        "SELECT data FROM documents WHERE company_id=? AND kind='nomenklatura' AND id=?",
      )
      .get(companyId, productId);
    const warehouse = await db
      .prepare(
        "SELECT data FROM documents WHERE company_id=? AND kind='warehouses' AND id=?",
      )
      .get(companyId, warehouseId);
    if ((!product || !warehouse) && !old)
      fail(404, "catalog_reference_not_found");
    const name = old?.productName ?? JSON.parse(product.data).name ?? productId;
    result.push({
      productId,
      warehouseId,
      productName: name,
      warehouseName:
        old?.warehouseName ?? JSON.parse(warehouse.data).name ?? warehouseId,
      description: item.description?.trim() || old?.description || name,
      unit:
        item.unit ??
        old?.unit ??
        (product ? JSON.parse(product.data).unit : null) ??
        "ед.",
      quantity: item.quantity,
      unitPrice: item.unitPrice,
    });
  }
  return result;
}

// Integer stock has no fractional minor-unit price. Split one receipt into at
// most two FIFO layers; their value equals the exact rounded line cost.
export function purchaseCostLayers(quantity, cost) {
  integer(quantity, "quantity", 1);
  integer(cost, "cost");
  const q = BigInt(quantity),
    c = BigInt(cost),
    base = c / q,
    remainder = c % q;
  return [
    { quantity: Number(q - remainder), unitCost: Number(base) },
    { quantity: Number(remainder), unitCost: Number(base + 1n) },
  ].filter((layer) => layer.quantity > 0);
}

export async function syncPurchaseStock(db, company, doc, authorize) {
  if (doc.kind !== "PURCHASE_GOODS") return;
  const existing = await db
    .prepare(
      "SELECT s.*,b.product_id,b.warehouse_id,b.scope,b.quantity,b.reserved,b.unit_cost FROM commercial_stock_layers s JOIN batches b ON b.company_id=s.company_id AND b.id=s.batch_id WHERE s.company_id=? AND s.document_id=? ORDER BY b.received_sequence",
    )
    .all(company.id, doc.id);
  const desired = new Map(
    doc.status === "POSTED"
      ? doc.data.items.map((line) => [lineKey(line), line])
      : [],
  );
  const keys = new Set([...existing.map((r) => r.line_key), ...desired.keys()]);
  let authorized = false;
  for (const key of keys) {
    const line = desired.get(key),
      old = existing.filter((r) => r.line_key === key),
      used = new Set();
    const cost = line
      ? doc.data.vatTreatment === "PENDING"
        ? line.net
        : line.total
      : 0;
    const layers = line ? purchaseCostLayers(Number(line.quantity), cost) : [];
    const plan = [];
    for (const layer of layers) {
      // Preserve matching layers, including already consumed units and reservations.
      let row = old.find(
        (r) =>
          !used.has(r.batch_id) &&
          r.unit_cost === layer.unitCost &&
          r.scope === doc.scope,
      );
      row ??= old.find(
        (r) =>
          !used.has(r.batch_id) &&
          r.quantity === r.original_quantity &&
          r.reserved <= layer.quantity,
      );
      if (row) used.add(row.batch_id);
      plan.push({ row, layer });
    }
    for (const row of old)
      if (!used.has(row.batch_id))
        plan.push({ row, layer: { quantity: 0, unitCost: row.unit_cost } });
    for (const { row, layer } of plan) {
      const delta = layer.quantity - (row?.original_quantity ?? 0);
      const nextQuantity = (row?.quantity ?? 0) + delta;
      const moved = row && row.scope !== doc.scope;
      const repriced = row && row.unit_cost !== layer.unitCost;
      if (
        row &&
        (nextQuantity < row.reserved ||
          (moved && row.reserved > 0) ||
          ((moved || repriced) && row.quantity !== row.original_quantity))
      )
        fail(409, "purchase_stock_consumed");
      const changed = !row || delta !== 0 || repriced || moved;
      if (!changed) continue;
      if (!authorized) {
        await authorize();
        authorized = true;
      }
      if (row) {
        await db
          .prepare(
            "UPDATE batches SET quantity=?,unit_cost=?,scope=? WHERE company_id=? AND id=?",
          )
          .run(
            nextQuantity,
            layer.unitCost,
            doc.scope,
            company.id,
            row.batch_id,
          );
        await db
          .prepare(
            "UPDATE commercial_stock_layers SET original_quantity=? WHERE batch_id=?",
          )
          .run(layer.quantity, row.batch_id);
      } else {
        const id = randomUUID();
        await db
          .prepare(
            "INSERT INTO batches(id,company_id,product_id,warehouse_id,scope,quantity,reserved,unit_cost,created_at) VALUES(?,?,?,?,?,?,0,?,?)",
          )
          .run(
            id,
            company.id,
            line.productId,
            line.warehouseId,
            doc.scope,
            layer.quantity,
            layer.unitCost,
            new Date().toISOString(),
          );
        await db
          .prepare("INSERT INTO commercial_stock_layers VALUES(?,?,?,?,?)")
          .run(company.id, doc.id, key, id, layer.quantity);
      }
    }
    // Current source projection, not a second independent raw warehouse receipt.
    const sourceLine = line ?? doc.data.items.find((l) => lineKey(l) === key);
    const [productId, warehouseId] = JSON.parse(key);
    const data = {
      documentId: doc.id,
      documentNumber: doc.number,
      status: line ? "POSTED" : "CANCELLED",
      productId,
      warehouseId,
      quantity: line ? Number(line.quantity) : 0,
      cost,
      scope: doc.scope,
      projectId: doc.project_id,
      businessDate: doc.business_date,
      productName: sourceLine?.productName ?? productId,
    };
    const movementId = `purchase:${doc.id}:${key}`;
    await db
      .prepare(
        "INSERT INTO movements(id,company_id,kind,data,created_at) VALUES(?,?,'RECEIPT',?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data",
      )
      .run(
        movementId,
        company.id,
        JSON.stringify(data),
        new Date().toISOString(),
      );
  }
}
