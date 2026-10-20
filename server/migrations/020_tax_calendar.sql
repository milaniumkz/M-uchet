CREATE TABLE tax_calendar_tasks (
 id TEXT PRIMARY KEY,company_id TEXT NOT NULL REFERENCES companies(id),
 title TEXT NOT NULL,due_date DATE NOT NULL,status TEXT NOT NULL CHECK(status IN ('OPEN','DONE','CANCELLED')),
 data JSONB NOT NULL,version INTEGER NOT NULL DEFAULT 1,created_at TEXT NOT NULL,updated_at TEXT NOT NULL
);
CREATE INDEX tax_calendar_company_date ON tax_calendar_tasks(company_id,due_date,id);
CREATE TABLE tax_preparations (
 company_id TEXT NOT NULL REFERENCES companies(id),month TEXT NOT NULL CHECK(month ~ '^\d{4}-(0[1-9]|1[0-2])$'),
 data JSONB NOT NULL,version INTEGER NOT NULL DEFAULT 1,updated_at TEXT NOT NULL,
 PRIMARY KEY(company_id,month)
);
INSERT INTO schema_versions VALUES(21);
