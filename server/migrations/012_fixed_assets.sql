CREATE TABLE fixed_assets(
 id TEXT PRIMARY KEY,company_id TEXT NOT NULL REFERENCES companies(id),
 inventory_number TEXT NOT NULL,name TEXT NOT NULL,scope TEXT NOT NULL,
 project_id TEXT,supplier_id TEXT NOT NULL,data JSONB NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('DRAFT','ACTIVE','WRITTEN_OFF')),
 depreciation_through TEXT,disposal_date TEXT,disposal_reason TEXT,
 version INTEGER NOT NULL DEFAULT 1,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,
 UNIQUE(company_id,id),UNIQUE(company_id,inventory_number),
 FOREIGN KEY(company_id,project_id) REFERENCES projects(company_id,id)
);
CREATE TABLE asset_postings(
 id BIGSERIAL PRIMARY KEY,company_id TEXT NOT NULL,asset_id TEXT NOT NULL,
 journal_id TEXT NOT NULL,kind TEXT NOT NULL,business_date TEXT NOT NULL,
 active BOOLEAN NOT NULL DEFAULT TRUE,
 FOREIGN KEY(company_id,asset_id) REFERENCES fixed_assets(company_id,id),
 FOREIGN KEY(company_id,journal_id) REFERENCES journal(company_id,id)
);
INSERT INTO schema_versions VALUES(13);
