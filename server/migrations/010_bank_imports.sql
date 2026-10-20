CREATE TABLE bank_imports(
 id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
 wallet_id TEXT NOT NULL, name TEXT NOT NULL, created_at TEXT NOT NULL,
 actor_id TEXT NOT NULL REFERENCES users(id),
 FOREIGN KEY(company_id,wallet_id) REFERENCES wallets(company_id,id),
 UNIQUE(company_id,id)
);
CREATE TABLE bank_import_rows(
 id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
 import_id TEXT NOT NULL, wallet_id TEXT NOT NULL,
 external_id TEXT NOT NULL, business_date TEXT NOT NULL,
 amount NUMERIC(20,0) NOT NULL CHECK(amount<>0), description TEXT NOT NULL,
 counterparty TEXT NOT NULL, fingerprint TEXT NOT NULL,
 classification TEXT, project_id TEXT, document_id TEXT,
 journal_id TEXT, payment_id TEXT, version INTEGER NOT NULL DEFAULT 1,
 FOREIGN KEY(company_id,import_id) REFERENCES bank_imports(company_id,id),
 FOREIGN KEY(company_id,wallet_id) REFERENCES wallets(company_id,id),
 FOREIGN KEY(company_id,project_id) REFERENCES projects(company_id,id),
 FOREIGN KEY(company_id,document_id) REFERENCES commercial_documents(company_id,id),
 FOREIGN KEY(company_id,journal_id) REFERENCES journal(company_id,id),
 UNIQUE(company_id,wallet_id,external_id), UNIQUE(company_id,id)
);
INSERT INTO schema_versions VALUES(11);
