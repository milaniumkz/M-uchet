ALTER TABLE wallets ADD UNIQUE(company_id,id);
ALTER TABLE journal ADD UNIQUE(company_id,id);
ALTER TABLE wallet_entries ADD CONSTRAINT wallet_entry_company_fk FOREIGN KEY(company_id,wallet_id) REFERENCES wallets(company_id,id);
CREATE TABLE document_sequences (
 company_id TEXT NOT NULL REFERENCES companies(id), kind TEXT NOT NULL, year INTEGER NOT NULL,
 next_number BIGINT NOT NULL CHECK(next_number>0), PRIMARY KEY(company_id,kind,year)
);
CREATE TABLE commercial_documents (
 id TEXT PRIMARY KEY,company_id TEXT NOT NULL REFERENCES companies(id),
 kind TEXT NOT NULL CHECK(kind IN ('SALE_INVOICE','SALE_ACT','PURCHASE_ACT')),
 number TEXT NOT NULL,status TEXT NOT NULL CHECK(status IN ('DRAFT','ISSUED','POSTED','CANCELLED')),
 business_date DATE NOT NULL,project_id TEXT,scope TEXT NOT NULL,
 data JSONB NOT NULL,version INTEGER NOT NULL DEFAULT 1,
 source_invoice_id TEXT UNIQUE REFERENCES commercial_documents(id),
 author_id TEXT NOT NULL REFERENCES users(id),created_at TEXT NOT NULL,updated_at TEXT NOT NULL,
 UNIQUE(company_id,kind,number),UNIQUE(company_id,id),
 FOREIGN KEY(company_id,project_id) REFERENCES projects(company_id,id),
 FOREIGN KEY(company_id,source_invoice_id) REFERENCES commercial_documents(company_id,id)
);
CREATE TABLE commercial_payments (
 id TEXT PRIMARY KEY,company_id TEXT NOT NULL,document_id TEXT NOT NULL,
 wallet_id TEXT NOT NULL REFERENCES wallets(id),amount NUMERIC(20,0) NOT NULL CHECK(amount>0),
 business_date DATE NOT NULL,journal_id TEXT NOT NULL REFERENCES journal(id),
 created_at TEXT NOT NULL,voided BOOLEAN NOT NULL DEFAULT FALSE,void_journal_id TEXT REFERENCES journal(id),
 FOREIGN KEY(company_id,wallet_id) REFERENCES wallets(company_id,id),
 FOREIGN KEY(company_id,document_id) REFERENCES commercial_documents(company_id,id),
 FOREIGN KEY(company_id,journal_id) REFERENCES journal(company_id,id)
);
CREATE TABLE commercial_postings (
 id BIGSERIAL PRIMARY KEY,company_id TEXT NOT NULL,document_id TEXT NOT NULL,
 journal_id TEXT NOT NULL REFERENCES journal(id),kind TEXT NOT NULL,
 active BOOLEAN NOT NULL DEFAULT TRUE,
 FOREIGN KEY(company_id,document_id) REFERENCES commercial_documents(company_id,id),
 FOREIGN KEY(company_id,journal_id) REFERENCES journal(company_id,id)
);
CREATE INDEX commercial_document_list ON commercial_documents(company_id,business_date,id);
CREATE INDEX commercial_payment_document ON commercial_payments(company_id,document_id);
INSERT INTO schema_versions VALUES(9);
ALTER TABLE company_settings ADD COLUMN legal_address TEXT NOT NULL DEFAULT '';
ALTER TABLE company_settings ADD COLUMN bank_iban TEXT NOT NULL DEFAULT '';
ALTER TABLE company_settings ADD COLUMN bank_bic TEXT NOT NULL DEFAULT '';
ALTER TABLE company_settings ADD COLUMN director_name TEXT NOT NULL DEFAULT '';
ALTER TABLE company_settings ADD COLUMN accountant_name TEXT NOT NULL DEFAULT '';
ALTER TABLE files ADD UNIQUE(company_id,id);
CREATE TABLE commercial_attachments (
 company_id TEXT NOT NULL,document_id TEXT NOT NULL,file_id TEXT NOT NULL,
 created_at TEXT NOT NULL,PRIMARY KEY(company_id,document_id,file_id),
 FOREIGN KEY(company_id,document_id) REFERENCES commercial_documents(company_id,id),
 FOREIGN KEY(company_id,file_id) REFERENCES files(company_id,id)
);
