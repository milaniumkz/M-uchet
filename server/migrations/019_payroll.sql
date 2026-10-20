ALTER TABLE employees ADD UNIQUE(company_id,id);
CREATE TABLE payroll_openings(
 company_id TEXT NOT NULL,employee_id TEXT NOT NULL,year INTEGER NOT NULL CHECK(year=2026),
 through_month TEXT NOT NULL CHECK(through_month ~ '^2026-(0[1-9]|1[0-2])$'),data JSONB NOT NULL,
 version INTEGER NOT NULL DEFAULT 1,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,
 PRIMARY KEY(company_id,employee_id,year),FOREIGN KEY(company_id,employee_id) REFERENCES employees(company_id,id)
);
CREATE TABLE payroll_records(
 id TEXT PRIMARY KEY,company_id TEXT NOT NULL,employee_id TEXT NOT NULL,
 month TEXT NOT NULL CHECK(month ~ '^2026-(0[1-9]|1[0-2])$'),
 status TEXT NOT NULL CHECK(status IN ('DRAFT','POSTED','CANCELLED')),
 project_id TEXT,scope TEXT NOT NULL,data JSONB NOT NULL,version INTEGER NOT NULL DEFAULT 1,
 created_at TEXT NOT NULL,updated_at TEXT NOT NULL,
 UNIQUE(company_id,id),UNIQUE(company_id,employee_id,month),
 FOREIGN KEY(company_id,employee_id) REFERENCES employees(company_id,id),
 FOREIGN KEY(company_id,project_id) REFERENCES projects(company_id,id)
);
CREATE TABLE payroll_postings(
 id BIGSERIAL PRIMARY KEY,company_id TEXT NOT NULL,payroll_id TEXT NOT NULL,journal_id TEXT NOT NULL,
 active BOOLEAN NOT NULL DEFAULT TRUE,kind TEXT NOT NULL,
 FOREIGN KEY(company_id,payroll_id) REFERENCES payroll_records(company_id,id),
 FOREIGN KEY(company_id,journal_id) REFERENCES journal(company_id,id)
);
CREATE TABLE payroll_payments(
 id TEXT PRIMARY KEY,company_id TEXT NOT NULL,payroll_id TEXT NOT NULL,wallet_id TEXT NOT NULL,
 amount NUMERIC(20,0) NOT NULL CHECK(amount>0),business_date DATE NOT NULL,journal_id TEXT NOT NULL,
 voided BOOLEAN NOT NULL DEFAULT FALSE,void_journal_id TEXT,version INTEGER NOT NULL DEFAULT 1,
 created_at TEXT NOT NULL,UNIQUE(company_id,id),
 FOREIGN KEY(company_id,payroll_id) REFERENCES payroll_records(company_id,id),
 FOREIGN KEY(company_id,wallet_id) REFERENCES wallets(company_id,id),
 FOREIGN KEY(company_id,journal_id) REFERENCES journal(company_id,id),
 FOREIGN KEY(company_id,void_journal_id) REFERENCES journal(company_id,id)
);
INSERT INTO schema_versions VALUES(20);
CREATE INDEX payroll_record_list ON payroll_records(company_id,month,project_id,scope,id);
CREATE INDEX payroll_posting_source ON payroll_postings(company_id,journal_id);
CREATE INDEX payroll_payment_source ON payroll_payments(company_id,journal_id);
CREATE INDEX goods_payment_source ON payments(company_id,journal_id);
