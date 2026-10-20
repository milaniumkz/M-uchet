import { randomUUID } from 'node:crypto';
import { fail, integer, scope, text, businessDate } from './security.js';

export function normalizeLines(input) {
  if (!Array.isArray(input.lines) || input.lines.length < 2 || input.lines.length > 100) fail(400, 'invalid_lines');
  let debits = 0, credits = 0;
  const lines = input.lines.map(line => {
    const account = text(line.account, 'account', 64);
    const debit = integer(line.debit ?? 0, 'debit');
    const credit = integer(line.credit ?? 0, 'credit');
    if ((debit === 0) === (credit === 0)) fail(400, 'one_side_required');
    debits += debit; credits += credit;
    return { account, debit, credit };
  });
  if (!Number.isSafeInteger(debits) || debits !== credits) fail(400, 'unbalanced_journal');
  return lines;
}

export async function projectReference(db, companyId, id) {
  if (id === undefined || id === null) return null;
  const row = await db.prepare('SELECT id FROM projects WHERE company_id=? AND id=?').get(companyId, text(id, 'projectId'));
  if (!row) fail(404, 'project_not_found');
  return row.id;
}

export async function postJournal(db, company, input) {
  const projectId = await projectReference(db, company.id, input.projectId);
  const ledgerScope = scope(input.scope);
  const lines = normalizeLines(input);
  const id = randomUUID();
  const date = businessDate(input.businessDate ?? company.businessDate, company.timezone);
  (await db.prepare('INSERT INTO journal(id,company_id,scope,currency,description,lines,created_at,business_date,project_id) VALUES(?,?,?,?,?,?,?,?,?)').run(
    id, company.id, ledgerScope, company.currency,
    text(input.description, 'description', 500), JSON.stringify(lines), new Date().toISOString(), date, projectId));
  for (const [position,line] of lines.entries()) await db.prepare('INSERT INTO journal_lines VALUES(?,?,?,?,?)').run(id,position,line.account,line.debit,line.credit);
  return { id, projectId, scope: ledgerScope, currency: company.currency, businessDate: date, lines };
}

export async function allocate(db, companyId, line, ledgerScope) {
  const rows = (await db.prepare(`SELECT * FROM batches WHERE company_id=? AND product_id=?
    AND warehouse_id=? AND scope=? ORDER BY received_sequence`).all(
    companyId, line.productId, line.warehouseId, ledgerScope));
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

export async function orderInput(db, companyId, body) {
  const ledgerScope = scope(body.scope);
  if (!Array.isArray(body.items) || !body.items.length || body.items.length > 100) fail(400, 'invalid_items');
  const seen = new Set();
  const items = [];
  for (const item of body.items) {
    const productId = text(item.productId, 'productId');
    const warehouseId = text(item.warehouseId, 'warehouseId');
    for (const [kind, id] of [['nomenklatura', productId], ['warehouses', warehouseId]]) {
      if (!(await db.prepare('SELECT 1 FROM documents WHERE company_id=? AND kind=? AND id=?').get(companyId, kind, id))) fail(404, 'catalog_reference_not_found');
    }
    const key = `${productId}:${warehouseId}`;
    if (seen.has(key)) fail(400, 'duplicate_order_line');
    seen.add(key);
    items.push({ productId, warehouseId, quantity: integer(item.quantity, 'quantity', 1), unitPrice: integer(item.unitPrice, 'unitPrice') });
  }
  const total = items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
  integer(total, 'order_total');
  return { scope: ledgerScope, projectId: await projectReference(db, companyId, body.projectId), items, total };
}
