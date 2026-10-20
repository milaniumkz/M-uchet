CREATE TABLE projects (
 id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
 name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', archived BOOLEAN NOT NULL DEFAULT FALSE,
 version INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, UNIQUE(company_id,id)
);
ALTER TABLE journal ADD COLUMN project_id TEXT;
ALTER TABLE journal ADD CONSTRAINT journal_project_company_fk FOREIGN KEY(company_id,project_id) REFERENCES projects(company_id,id);
CREATE INDEX journal_project_report ON journal(company_id,project_id,business_date);
INSERT INTO schema_versions VALUES(6);
