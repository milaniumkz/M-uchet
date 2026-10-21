import { randomUUID, createHash } from "node:crypto";
import { fail, text, integer, scope, businessDate } from "./security.js";
import { allocate, postJournal, projectReference } from "./accounting.js";
import { readSnapshot } from "./db.js";
const now = () => new Date().toISOString();
export const stockCountSource = (db, companyId, id) =>
  db
    .prepare(
      "SELECT count_id FROM stock_count_postings WHERE company_id=? AND journal_id=?",
    )
    .get(companyId, id);

export function registerStockCounts(
  app,
  { db, auth, access, command, object, pageLimit },
) {
  const route = (method, path, handler) =>
    app.route({
      method,
      url: "/v1/companies/:companyId/inventory/counts" + path,
      preHandler: auth,
      handler,
    });
  const get = async (companyId, id) => {
    const row = await db
      .prepare("SELECT * FROM stock_counts WHERE company_id=? AND id=?")
      .get(companyId, id);
    if (!row) fail(404, "stock_count_not_found");
    return { ...row, data: JSON.parse(row.data) };
  };
  const capture = async (companyId, warehouseId, ledgerScope, productId) => {
    const product = await db
      .prepare(
        "SELECT data FROM documents WHERE company_id=? AND kind='nomenklatura' AND id=?",
      )
      .get(companyId, productId);
    if (!product) fail(404, "catalog_reference_not_found");
    const rows = await db
      .prepare(
        "SELECT id,quantity,reserved,unit_cost FROM batches WHERE company_id=? AND warehouse_id=? AND scope=? AND product_id=? ORDER BY id",
      )
      .all(companyId, warehouseId, ledgerScope, productId);
    let quantity = 0,
      reserved = 0;
    for (const r of rows) {
      quantity += r.quantity;
      reserved += r.reserved;
    }
    integer(quantity, "stock_count_quantity");
    integer(reserved, "stock_count_reserved");
    return {
      expectedQuantity: quantity,
      reserved,
      stockFingerprint: createHash("sha256")
        .update(JSON.stringify(rows))
        .digest("hex"),
      productName: JSON.parse(product.data).name ?? productId,
    };
  };
  const input = async (company, body, previous) => {
    const warehouseId = text(body.warehouseId, "warehouseId"),
      ledgerScope = scope(body.scope);
    if (
      !(await db
        .prepare(
          "SELECT 1 FROM documents WHERE company_id=? AND kind='warehouses' AND id=?",
        )
        .get(company.id, warehouseId))
    )
      fail(404, "catalog_reference_not_found");
    const projectId = await projectReference(db, company.id, body.projectId),
      date = businessDate(body.businessDate, company.timezone);
    if (
      !Array.isArray(body.lines) ||
      !body.lines.length ||
      body.lines.length > 100
    )
      fail(400, "invalid_stock_count_lines");
    const seen = new Set(),
      lines = [];
    for (const line of body.lines) {
      const productId = text(line.productId, "productId");
      if (seen.has(productId)) fail(400, "duplicate_stock_count_line");
      seen.add(productId);
      const countedQuantity = integer(line.countedQuantity, "countedQuantity"),
        surplusUnitCost = integer(line.surplusUnitCost ?? 0, "surplusUnitCost");
      const old =
        previous?.warehouse_id === warehouseId && previous.scope === ledgerScope
          ? previous.data.lines.find((l) => l.productId === productId)
          : null;
      const expected =
        old && body.rebase !== true
          ? {
              expectedQuantity: old.expectedQuantity,
              reserved: old.reserved,
              stockFingerprint: old.stockFingerprint,
              productName: old.productName,
            }
          : await capture(company.id, warehouseId, ledgerScope, productId);
      lines.push({ productId, countedQuantity, surplusUnitCost, ...expected });
    }
    return {
      scope: ledgerScope,
      warehouseId,
      projectId,
      businessDate: date,
      data: {
        reason: text(body.reason, "reason", 1000),
        valuationConfirmed: body.valuationConfirmed === true,
        lines,
      },
    };
  };
  const history = async (request, old) =>
    db
      .prepare(
        "INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)",
      )
      .run(
        old.company_id,
        "stock_count",
        old.id,
        JSON.stringify(old),
        request.user.id,
      );
  const undoStock = async (company, doc) => {
    for (const line of doc.data.lines) {
      const effect = line.effect;
      if (!effect) continue;
      if (effect.batchId) {
        const result = await db
          .prepare(
            "UPDATE batches SET quantity=quantity-? WHERE company_id=? AND id=? AND quantity-reserved>=?",
          )
          .run(effect.delta, company.id, effect.batchId, effect.delta);
        if (!result.changes) fail(409, "stock_count_surplus_in_use");
      }
      for (const a of effect.allocations ?? [])
        await db
          .prepare(
            "UPDATE batches SET quantity=quantity+? WHERE company_id=? AND id=?",
          )
          .run(a.quantity, company.id, a.batchId);
    }
  };
  const applyStock = async (company, doc, checkSnapshot) => {
    for (const line of doc.data.lines) {
      const state = await capture(
        company.id,
        doc.warehouse_id,
        doc.scope,
        line.productId,
      );
      if (checkSnapshot && state.stockFingerprint !== line.stockFingerprint)
        fail(409, "stock_count_stale");
      const delta = line.countedQuantity - line.expectedQuantity;
      const effect = { delta, cost: 0 };
      if (delta > 0) {
        if (!doc.data.valuationConfirmed)
          fail(422, "stock_count_valuation_confirmation_required");
        effect.cost = integer(
          delta * line.surplusUnitCost,
          "stock_count_value",
        );
        effect.batchId = randomUUID();
        await db
          .prepare(
            "INSERT INTO batches(id,company_id,product_id,warehouse_id,scope,quantity,reserved,unit_cost,created_at) VALUES(?,?,?,?,?,?,0,?,?)",
          )
          .run(
            effect.batchId,
            company.id,
            line.productId,
            doc.warehouse_id,
            doc.scope,
            delta,
            line.surplusUnitCost,
            now(),
          );
      } else if (delta < 0) {
        effect.allocations = await allocate(
          db,
          company.id,
          {
            productId: line.productId,
            warehouseId: doc.warehouse_id,
            quantity: -delta,
          },
          doc.scope,
        );
        for (const a of effect.allocations) {
          await db
            .prepare(
              "UPDATE batches SET quantity=quantity-? WHERE company_id=? AND id=?",
            )
            .run(a.quantity, company.id, a.batchId);
          effect.cost += a.quantity * a.unitCost;
        }
        integer(effect.cost, "stock_count_value");
      }
      line.effect = effect;
    }
  };
  const project = async (company, doc) => {
    const previous = await db
      .prepare(
        "SELECT j.* FROM stock_count_postings p JOIN journal j ON j.id=p.journal_id WHERE p.company_id=? AND p.count_id=? AND p.active",
      )
      .all(company.id, doc.id);
    for (const entry of previous) {
      const reversal = await postJournal(db, company, {
        scope: entry.scope,
        projectId: entry.project_id,
        businessDate: entry.business_date,
        description: `Исправление инвентаризации ${doc.id}`,
        lines: JSON.parse(entry.lines).map((l) => ({
          account: l.account,
          debit: l.credit,
          credit: l.debit,
        })),
      });
      await db
        .prepare("INSERT INTO stock_count_postings VALUES(?,?,?,FALSE)")
        .run(company.id, doc.id, reversal.id);
    }
    await db
      .prepare(
        "UPDATE stock_count_postings SET active=FALSE WHERE company_id=? AND count_id=? AND active",
      )
      .run(company.id, doc.id);
    if (doc.status !== "POSTED") return;
    for (const line of doc.data.lines) {
      const e = line.effect;
      if (!e?.cost) continue;
      const entry = await postJournal(db, company, {
        scope: doc.scope,
        projectId: doc.project_id,
        businessDate: doc.business_date,
        description: `Инвентаризация ${doc.id}: ${line.productName}`,
        lines:
          e.delta > 0
            ? [
                { account: "inventory", debit: e.cost },
                { account: "inventory_surplus", credit: e.cost },
              ]
            : [
                { account: "inventory_loss", debit: e.cost },
                { account: "inventory", credit: e.cost },
              ],
      });
      await db
        .prepare("INSERT INTO stock_count_postings VALUES(?,?,?,TRUE)")
        .run(company.id, doc.id, entry.id);
    }
  };
  const postingRights = async (request, doc) => {
    for (const l of doc.data.lines) {
      if (l.countedQuantity > l.expectedQuantity)
        await access(request, "inventory.receive");
      if (l.countedQuantity < l.expectedQuantity)
        await access(request, "inventory.writeoff");
    }
  };
  const persist = async (doc) => {
    await db
      .prepare(
        "UPDATE stock_counts SET scope=?,warehouse_id=?,project_id=?,business_date=?,data=?,status=?,version=version+1,updated_at=? WHERE company_id=? AND id=?",
      )
      .run(
        doc.scope,
        doc.warehouse_id,
        doc.project_id,
        doc.business_date,
        JSON.stringify(doc.data),
        doc.status,
        now(),
        doc.company_id,
        doc.id,
      );
    return get(doc.company_id, doc.id);
  };
  route("GET", "", (request) =>
    readSnapshot(db, async () => {
      const company = await access(request, "inventory.read"),
        selectedScope =
          request.query.scope === undefined
            ? undefined
            : scope(request.query.scope),
        warehouseId = request.query.warehouseId;
      if (
        warehouseId !== undefined &&
        !(await db
          .prepare(
            "SELECT 1 FROM documents WHERE company_id=? AND kind='warehouses' AND id=?",
          )
          .get(company.id, text(warehouseId, "warehouseId")))
      )
        fail(404, "catalog_reference_not_found");
      const rows = await db
        .prepare(
          `SELECT * FROM stock_counts WHERE company_id=? AND id>? ${selectedScope === undefined ? "" : "AND scope=?"} ${warehouseId === undefined ? "" : "AND warehouse_id=?"} ORDER BY id LIMIT ?`,
        )
        .all(
          company.id,
          request.query.after ?? "",
          ...(selectedScope === undefined ? [] : [selectedScope]),
          ...(warehouseId === undefined ? [] : [warehouseId]),
          pageLimit(request.query),
        );
      return {
        businessDate: businessDate(undefined, company.timezone),
        items: rows.map((r) => ({ ...r, data: JSON.parse(r.data) })),
        nextCursor:
          rows.length === pageLimit(request.query) ? rows.at(-1).id : null,
      };
    }),
  );
  route("GET", "/:id", async (request) => {
    await access(request, "inventory.read");
    return get(request.params.companyId, request.params.id);
  });
  route("GET", "/:id/history", async (request) => {
    await access(request, "inventory.read");
    await get(request.params.companyId, request.params.id);
    return {
      items: await db
        .prepare(
          "SELECT h.*,u.name AS actor_name FROM entity_history h JOIN users u ON u.id=h.actor_id WHERE h.company_id=? AND h.kind='stock_count' AND h.entity_id=? ORDER BY revision DESC LIMIT 200",
        )
        .all(request.params.companyId, request.params.id),
    };
  });
  route("POST", "", (request) =>
    command(
      request,
      "inventory.count",
      "stock_count.create",
      async (company) => {
        await access(request, "inventory.read");
        const p = await input(company, object(request.body));
        const id = randomUUID(),
          time = now();
        await db
          .prepare(
            "INSERT INTO stock_counts VALUES(?,?,'DRAFT',1,?,?,?,?,?,?,?,?)",
          )
          .run(
            id,
            company.id,
            p.scope,
            p.warehouseId,
            p.projectId,
            p.businessDate,
            JSON.stringify(p.data),
            request.user.id,
            time,
            time,
          );
        return get(company.id, id);
      },
    ),
  );
  route("PUT", "/:id", (request) =>
    command(request, "inventory.count", "stock_count.edit", async (company) => {
      await access(request, "inventory.read");
      const old = await get(company.id, request.params.id),
        body = object(request.body);
      if (body.version !== old.version) fail(409, "version_conflict");
      if (old.status === "POSTED" && body.rebase === true)
        fail(409, "stock_count_posted_rebase");
      const parsed = await input(
        company,
        {
          ...old.data,
          warehouseId: old.warehouse_id,
          scope: old.scope,
          businessDate: old.business_date,
          projectId: old.project_id,
          ...body,
        },
        old,
      );
      const doc = {
        ...old,
        scope: parsed.scope,
        warehouse_id: parsed.warehouseId,
        project_id: parsed.projectId,
        business_date: parsed.businessDate,
        data: parsed.data,
      };
      await history(request, old);
      if (old.status === "POSTED") {
        await postingRights(request, old);
        await postingRights(request, doc);
        if (
          doc.data.lines.some((l) => l.countedQuantity > l.expectedQuantity) &&
          !doc.data.valuationConfirmed
        )
          fail(422, "stock_count_valuation_confirmation_required");
        const oldByProduct = new Map(
          old.data.lines.map((l) => [l.productId, l]),
        );
        const samePool =
          old.scope === doc.scope && old.warehouse_id === doc.warehouse_id;
        const retained = new Set(),
          changedNew = [];
        const shape = (l) =>
          JSON.stringify([
            l.countedQuantity,
            l.expectedQuantity,
            l.countedQuantity > l.expectedQuantity ? l.surplusUnitCost : 0,
          ]);
        for (const line of doc.data.lines) {
          const previous = samePool
            ? oldByProduct.get(line.productId)
            : undefined;
          if (previous && shape(previous) === shape(line)) {
            line.effect = previous.effect;
            retained.add(line.productId);
          } else if (
            previous?.effect?.delta > 0 &&
            line.countedQuantity >= line.expectedQuantity &&
            line.surplusUnitCost === previous.surplusUnitCost
          ) {
            const oldEffect = previous.effect,
              delta = line.countedQuantity - line.expectedQuantity,
              change = delta - oldEffect.delta;
            const cost = integer(
              delta * line.surplusUnitCost,
              "stock_count_value",
            );
            const updated = await db
              .prepare(
                "UPDATE batches SET quantity=quantity+? WHERE company_id=? AND id=? AND quantity+?>=reserved",
              )
              .run(change, company.id, oldEffect.batchId, change);
            if (!updated.changes) fail(409, "stock_count_surplus_in_use");
            line.effect = { ...oldEffect, delta, cost };
            retained.add(line.productId);
          } else {
            changedNew.push(line);
          }
        }
        const changedOld = old.data.lines.filter(
          (l) => !retained.has(l.productId),
        );
        await undoStock(company, {
          ...old,
          data: { ...old.data, lines: changedOld },
        });
        await applyStock(
          company,
          { ...doc, data: { ...doc.data, lines: changedNew } },
          false,
        );
        await project(company, doc);
      }
      return persist(doc);
    }),
  );
  for (const action of ["post", "cancel"])
    route("POST", "/:id/" + action, (request) =>
      command(
        request,
        "inventory.count",
        "stock_count." + action,
        async (company) => {
          await access(request, "inventory.read");
          const doc = await get(company.id, request.params.id);
          if (object(request.body).version !== doc.version)
            fail(409, "version_conflict");
          if (
            (action === "post" && doc.status === "POSTED") ||
            (action === "cancel" && doc.status === "CANCELLED")
          )
            return doc;
          await history(request, doc);
          await postingRights(request, doc);
          if (action === "post") {
            await applyStock(company, doc, true);
            doc.status = "POSTED";
          } else {
            if (doc.status === "POSTED") await undoStock(company, doc);
            doc.status = "CANCELLED";
          }
          await project(company, doc);
          return persist(doc);
        },
      ),
    );
}
