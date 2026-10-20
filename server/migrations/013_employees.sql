CREATE TABLE employees(
 id TEXT PRIMARY KEY,company_id TEXT NOT NULL REFERENCES companies(id),
 name TEXT NOT NULL,identifier TEXT,job_title TEXT NOT NULL,
 hire_date TEXT NOT NULL,birth_date TEXT,termination_date TEXT,
 gross_base NUMERIC(20,0) NOT NULL CHECK(gross_base>=0),project_id TEXT,
 status TEXT NOT NULL CHECK(status IN ('ACTIVE','INACTIVE')),
 data JSONB NOT NULL,version INTEGER NOT NULL DEFAULT 1,
 created_at TEXT NOT NULL,updated_at TEXT NOT NULL,
 UNIQUE(company_id,id),UNIQUE(company_id,identifier),
 FOREIGN KEY(company_id,project_id) REFERENCES projects(company_id,id)
);
INSERT INTO schema_versions VALUES(14);
