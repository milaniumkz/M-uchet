CREATE TABLE purchase_returns (
 id TEXT PRIMARY KEY,company_id TEXT NOT NULL,document_id TEXT NOT NULL,
 number TEXT NOT NULL,status TEXT NOT NULL CHECK(status IN ('POSTED','CANCELLED')),
 business_date DATE NOT NULL,reason TEXT NOT NULL,data JSONB NOT NULL,
 version INTEGER NOT NULL DEFAULT 1,author_id TEXT NOT NULL REFERENCES users(id),
 created_at TEXT NOT NULL,updated_at TEXT NOT NULL,
 UNIQUE(company_id,id),UNIQUE(company_id,number),
 FOREIGN KEY(company_id,document_id) REFERENCES commercial_documents(company_id,id)
);
CREATE INDEX purchase_returns_document ON purchase_returns(company_id,document_id,business_date,id);
INSERT INTO schema_versions VALUES(26);
