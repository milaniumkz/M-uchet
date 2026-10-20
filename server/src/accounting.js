import { randomUUID } from 'node:crypto';
import { fail, integer, scope, text } from './security.js';

export function postJournal(db, company, input) {
  const ledgerScope = scope(input.scope);
  if (!Array.isArray(input.lines) || input.lines.length < 2 || input.lines.length > 100) fail(400, 'invalid_lines');
  let debits = 0, credits = 0;
  const lines = input.lines.map(line => {
    const account = text(line.account, 'account', 32);
    const debit = integer(line.debit ?? 0, 'debit');
    const credit = integer(line.credit ?? 0, 'credit');
    if ((debit === 0) === (credit === 0)) fail(400, 'one_side_required');
    debits += debit; credits += credit;
    return { account, debit, credit };
  });
  if (!Number.isSafeInteger(debits) || debits !== credits) fail(400, 'unbalanced_journal');
  const id = randomUUID();
  db.prepare('INSERT INTO journal VALUES(?,?,?,?,?,?,?)').run(
    id, company.id, ledgerScope, company.currency,
    text(input.description, 'description', 500), JSON.stringify(lines), new Date().toISOString());
  return { id, scope: ledgerScope, currency: company.currency, lines };
}

export function allocate(db, companyId, line, ledgerScope) {
  const rows = db.prepare(`SELECT * FROM batches WHERE company_id=? AND product_id=?
    AND warehouse_id=? AND scope=? ORDER BY created_at,rowid`).all(
    companyId, line.productId, line.warehouseId, ledgerScope);
  let remaining = line.quantity;
  const allocations = [];
  for (const batch of rows) {
    const quantity = Math.min(remaining, batch.quantity - batch.reserved);
    if (quantity > 0) allocations.push({ batchId: batch.id, quantity, unitCost: batch.unit_cost });
    remaining -= quantity;
    if (remaining === 0) break;
  }
  if (remaining > 0) fail(409, 'insufficient_inventory');
  return allocations;
}

export function orderInput(db, companyId, body) {
  const ledgerScope = scope(body.scope);
  if (!Array.isArray(body.items) || !body.items.length || body.items.length > 100) fail(400, 'invalid_items');
  const seen = new Set();
  const items = body.items.map(item => {
    const productId = text(item.productId, 'productId');
    const warehouseId = text(item.warehouseId, 'warehouseId');
    for (const [kind, id] of [['nomenklatura', productId], ['warehouses', warehouseId]]) {
      if (!db.prepare('SELECT 1 FROM documents WHERE company_id=? AND kind=? AND id=?').get(companyId, kind, id)) fail(404, 'catalog_reference_not_found');
    }
    const key = `${productId}:${warehouseId}`;
    if (seen.has(key)) fail(400, 'duplicate_order_line');
    seen.add(key);
    return { productId, warehouseId, quantity: integer(item.quantity, 'quantity', 1), unitPrice: integer(item.unitPrice, 'unitPrice') };
  });
  const total = items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
  integer(total, 'order_total');
  return { scope: ledgerScope, items, total };
}
