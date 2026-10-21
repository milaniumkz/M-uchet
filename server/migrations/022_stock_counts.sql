CREATE TABLE stock_counts(
 id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
 status TEXT NOT NULL CHECK(status IN ('DRAFT','POSTED','CANCELLED')),
 version INTEGER NOT NULL DEFAULT 1,
 scope TEXT NOT NULL CHECK(scope IN ('ACCOUNTING','MANAGEMENT','BOTH')),
 warehouse_id TEXT NOT NULL,project_id TEXT,business_date DATE NOT NULL,
 data TEXT NOT NULL,author_id TEXT NOT NULL REFERENCES users(id),created_at TEXT NOT NULL,updated_at TEXT NOT NULL,
 UNIQUE(company_id,id),FOREIGN KEY(company_id,project_id) REFERENCES projects(company_id,id)
);
CREATE TABLE stock_count_postings(
 company_id TEXT NOT NULL,count_id TEXT NOT NULL,journal_id TEXT NOT NULL,active BOOLEAN NOT NULL DEFAULT TRUE,
 PRIMARY KEY(company_id,journal_id),
 FOREIGN KEY(company_id,count_id) REFERENCES stock_counts(company_id,id),
 FOREIGN KEY(company_id,journal_id) REFERENCES journal(company_id,id)
);
CREATE INDEX stock_counts_company ON stock_counts(company_id,id);
INSERT INTO schema_versions VALUES(23);
