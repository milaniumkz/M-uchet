import { randomUUID } from "node:crypto";
import { fail, text, businessDate } from "./security.js";

export function registerTaxCalendarRoutes(
  app,
  { db, auth, access, command, object, pageLimit },
) {
  const route = (method, path, handler) =>
    app.route({
      method,
      url: "/v1/companies/:companyId/tax-calendar" + path,
      preHandler: auth,
      handler,
    });
  const month = (raw) => {
    if (
      typeof raw !== "string" ||
      !/^\d{4}-(0[1-9]|1[0-2])$/.test(raw) ||
      raw.startsWith("0000")
    )
      fail(400, "invalid_period");
    return raw;
  };
  const get = async (company, id) => {
    const row = await db
      .prepare("SELECT * FROM tax_calendar_tasks WHERE company_id=? AND id=?")
      .get(company, id);
    if (!row) fail(404, "calendar_task_not_found");
    return row;
  };
  const snapshot = async (request, kind, id, value) =>
    db
      .prepare(
        "INSERT INTO entity_history(company_id,kind,entity_id,snapshot,actor_id) VALUES(?,?,?,?,?)",
      )
      .run(
        request.params.companyId,
        kind,
        id,
        JSON.stringify(value),
        request.user.id,
      );
  const input = (body) => {
    const title = text(body.title, "title", 250),
      dueDate = businessDate(text(body.dueDate, "dueDate", 10));
    if (
      !["OPEN", "DONE", "CANCELLED"].includes(body.status) ||
      !["TAX", "REPORT", "PREPARATION", "OTHER"].includes(body.category)
    )
      fail(400, "invalid_calendar_task");
    const notes = body.notes ?? "",
      source = body.source ?? "";
    if (
      typeof notes !== "string" ||
      notes.length > 4000 ||
      typeof source !== "string" ||
      source.length > 2000
    )
      fail(400, "invalid_calendar_task");
    if (body.dueDateConfirmed !== true)
      fail(422, "calendar_date_confirmation_required");
    // Sources are user-entered evidence, never fetched or declared legally verified.
    return {
      title,
      dueDate,
      status: body.status,
      data: {
        category: body.category,
        notes: notes.trim(),
        source: source.trim(),
        dueDateConfirmed: true,
        sourceKind: "MANUAL",
      },
    };
  };
  route("GET", "", async (request) => {
    const company = await access(request, "tax-calendar.read");
    const from = businessDate(request.query.from ?? "0001-01-01"),
      to = businessDate(request.query.to ?? "9999-12-31");
    if (from > to) fail(400, "invalid_date_range");
    const status = request.query.status;
    if (status !== undefined && !["OPEN", "DONE", "CANCELLED"].includes(status))
      fail(400, "invalid_calendar_task");
    const filters = [company.id, from, to, ...(status ? [status] : [])],
      where = `company_id=? AND due_date>=? AND due_date<=?${status ? " AND status=?" : ""}`;
    const items = await db
      .prepare(
        `SELECT * FROM tax_calendar_tasks WHERE ${where} AND id>? ORDER BY id LIMIT ?`,
      )
      .all(...filters, request.query.after ?? "", pageLimit(request.query));
    const today = businessDate(undefined, company.timezone);
    const counts = await db
      .prepare(
        `SELECT count(*) AS total,count(*) FILTER(WHERE status='OPEN') AS open,count(*) FILTER(WHERE status='DONE') AS done,count(*) FILTER(WHERE status='OPEN' AND due_date<?) AS overdue FROM tax_calendar_tasks WHERE ${where}`,
      )
      .get(today, ...filters);
    return {
      items,
      counts,
      businessDate: today,
      from,
      to,
      companyWide: true,
      automaticOfficialDeadlines: false,
      nextCursor:
        items.length === pageLimit(request.query) ? items.at(-1).id : null,
    };
  });
  route("POST", "", (request) =>
    command(
      request,
      "tax-calendar.write",
      "tax-calendar.create",
      async (company) => {
        const d = input(object(request.body)),
          id = randomUUID(),
          now = new Date().toISOString();
        await db
          .prepare(
            "INSERT INTO tax_calendar_tasks(id,company_id,title,due_date,status,data,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?)",
          )
          .run(
            id,
            company.id,
            d.title,
            d.dueDate,
            d.status,
            JSON.stringify(d.data),
            now,
            now,
          );
        return get(company.id, id);
      },
    ),
  );
  route("GET", "/:id", async (request) => {
    const company = await access(request, "tax-calendar.read");
    return get(company.id, text(request.params.id, "taskId"));
  });
  route("PUT", "/:id", (request) =>
    command(
      request,
      "tax-calendar.write",
      "tax-calendar.edit",
      async (company) => {
        const old = await get(company.id, request.params.id),
          body = object(request.body);
        if (body.version !== old.version) fail(409, "version_conflict");
        const d = input(body);
        await snapshot(request, "tax_calendar_task", old.id, old);
        await db
          .prepare(
            "UPDATE tax_calendar_tasks SET title=?,due_date=?,status=?,data=?,version=version+1,updated_at=? WHERE id=?",
          )
          .run(
            d.title,
            d.dueDate,
            d.status,
            JSON.stringify(d.data),
            new Date().toISOString(),
            old.id,
          );
        return get(company.id, old.id);
      },
    ),
  );
  route("GET", "/:id/history", async (request) => {
    const company = await access(request, "tax-calendar.read");
    await get(company.id, request.params.id);
    return {
      items: await db
        .prepare(
          "SELECT h.*,u.name AS actor_name FROM entity_history h JOIN users u ON u.id=h.actor_id WHERE h.company_id=? AND h.kind='tax_calendar_task' AND h.entity_id=? ORDER BY revision DESC",
        )
        .all(company.id, request.params.id),
    };
  });
  const preparation = async (company, selected) => {
    const settings = await db
      .prepare("SELECT * FROM company_settings WHERE company_id=?")
      .get(company);
    const row = await db
      .prepare("SELECT * FROM tax_preparations WHERE company_id=? AND month=?")
      .get(company, selected);
    const data = row?.data ?? {
      profileChecked: false,
      documentsChecked: false,
      controlsChecked: false,
      settingsVersion: null,
    };
    const profileCurrent =
      !!settings && data.settingsVersion === settings.version;
    return {
      id: selected,
      month: selected,
      version: row?.version ?? 0,
      data,
      settings: settings ?? null,
      profileCurrent,
      ready:
        profileCurrent &&
        data.profileChecked &&
        data.documentsChecked &&
        data.controlsChecked,
      officialReportGenerated: false,
    };
  };
  route("GET", "/preparation/:month", async (request) => {
    const company = await access(request, "tax-calendar.read");
    await access(request, "organization.read");
    return preparation(company.id, month(request.params.month));
  });
  route("PUT", "/preparation/:month", (request) =>
    command(
      request,
      "tax-calendar.write",
      "tax-calendar.prepare",
      async (company) => {
        await access(request, "organization.read");
        const selected = month(request.params.month),
          body = object(request.body),
          old = await preparation(company.id, selected);
        if (body.version !== old.version) fail(409, "version_conflict");
        for (const key of [
          "profileChecked",
          "documentsChecked",
          "controlsChecked",
        ])
          if (typeof body[key] !== "boolean") fail(400, "invalid_preparation");
        if (
          body.profileChecked &&
          (!old.settings?.identifier ||
            !old.settings.legal_form ||
            !old.settings.tax_regime)
        )
          fail(422, "company_profile_incomplete");
        if (body.settingsVersion !== (old.settings?.version ?? null))
          fail(409, "version_conflict");
        const data = {
          profileChecked: body.profileChecked,
          documentsChecked: body.documentsChecked,
          controlsChecked: body.controlsChecked,
          settingsVersion: body.settingsVersion,
        };
        if (old.version)
          await snapshot(request, "tax_preparation", selected, old);
        await db
          .prepare(
            "INSERT INTO tax_preparations(company_id,month,data,updated_at) VALUES(?,?,?,?) ON CONFLICT(company_id,month) DO UPDATE SET data=excluded.data,updated_at=excluded.updated_at,version=tax_preparations.version+1",
          )
          .run(
            company.id,
            selected,
            JSON.stringify(data),
            new Date().toISOString(),
          );
        return preparation(company.id, selected);
      },
    ),
  );
}
