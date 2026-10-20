import { fail } from "./security.js";

export function registerSearchRoutes(app, { db, auth }) {
  app.get(
    "/v1/companies/:companyId/search",
    { preHandler: auth },
    async (request) => {
      const company = request.params.companyId;
      const membership = await db
        .prepare(
          "SELECT role,permissions FROM memberships WHERE company_id=? AND user_id=?",
        )
        .get(company, request.user.id);
      if (!membership) fail(404, "company_not_found");
      const allowed = new Set(JSON.parse(membership.permissions));
      const can = (...required) =>
        membership.role === "owner" || required.every((p) => allowed.has(p));
      const q =
        typeof request.query.q === "string" ? request.query.q.trim() : "";
      if (q.length < 2 || q.length > 160) fail(400, "invalid_search");
      const limit = Number(request.query.limit ?? 20);
      if (!Number.isInteger(limit) || limit < 1 || limit > 50)
        fail(400, "invalid_limit");
      const pattern = "%" + q.replace(/[\\%_]/g, (c) => "\\" + c) + "%",
        cap = limit + 1;
      const groups = [];
      const add = async (permissions, sql, args) => {
        if (can(...permissions))
          groups.push(await db.prepare(sql).all(company, ...args, cap));
      };
      await add(
        ["projects.read", "reports.read"],
        "SELECT id,name AS title,'PROJECT' AS kind,description AS detail FROM projects WHERE company_id=? AND (name ILIKE ? OR description ILIKE ?) ORDER BY name,id LIMIT ?",
        [pattern, pattern],
      );
      await add(
        ["documents.read"],
        "SELECT id,number AS title,kind,business_date::text AS detail FROM commercial_documents WHERE company_id=? AND (number ILIKE ? OR data->'counterparty'->>'name' ILIKE ?) ORDER BY business_date DESC,id LIMIT ?",
        [pattern, pattern],
      );
      await add(
        ["orders.read", "catalog.read"],
        "SELECT id,COALESCE(data::jsonb->>'number',id) AS title,'GOODS' AS kind,COALESCE(data::jsonb->>'businessDate','') AS detail FROM orders WHERE company_id=? AND (data::jsonb->>'number' ILIKE ? OR data::jsonb->'counterparty'->>'name' ILIKE ? OR id=?) ORDER BY created_at DESC,id LIMIT ?",
        [pattern, pattern, q],
      );
      await add(
        ["catalog.read"],
        "SELECT id,COALESCE(data::jsonb->>'name',id) AS title,kind,COALESCE(data::jsonb->>'article','') AS detail FROM documents WHERE company_id=? AND kind IN ('clients','suppliers','services','nomenklatura','warehouses') AND (data::jsonb->>'name' ILIKE ? OR data::jsonb->>'identifier' ILIKE ? OR data::jsonb->>'article' ILIKE ?) ORDER BY kind,id LIMIT ?",
        [pattern, pattern, pattern],
      );
      await add(
        ["employees.read"],
        "SELECT id,name AS title,'EMPLOYEE' AS kind,job_title AS detail FROM employees WHERE company_id=? AND (name ILIKE ? OR identifier ILIKE ? OR job_title ILIKE ?) ORDER BY name,id LIMIT ?",
        [pattern, pattern, pattern],
      );
      await add(
        ["assets.read"],
        "SELECT id,name AS title,'ASSET' AS kind,inventory_number AS detail FROM fixed_assets WHERE company_id=? AND (name ILIKE ? OR inventory_number ILIKE ?) ORDER BY name,id LIMIT ?",
        [pattern, pattern],
      );
      await add(
        ["debts.read"],
        "SELECT id,COALESCE(data->'counterparty'->>'name',id) AS title,'DEBT' AS kind,business_date::text AS detail FROM debts WHERE company_id=? AND (data->'counterparty'->>'name' ILIKE ? OR data->>'notes' ILIKE ? OR id=?) ORDER BY business_date DESC,id LIMIT ?",
        [pattern, pattern, q],
      );
      const all = groups.flat(),
        lower = q.toLocaleLowerCase("ru");
      all.sort(
        (a, b) =>
          Number(b.title.toLocaleLowerCase("ru").startsWith(lower)) -
            Number(a.title.toLocaleLowerCase("ru").startsWith(lower)) ||
          a.title.localeCompare(b.title, "ru") ||
          a.kind.localeCompare(b.kind) ||
          a.id.localeCompare(b.id),
      );
      return {
        query: q,
        items: all.slice(0, limit),
        hasMore: all.length > limit,
        limit,
        companyWide: true,
      };
    },
  );
}
