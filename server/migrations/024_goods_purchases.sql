ALTER TABLE commercial_documents DROP CONSTRAINT commercial_documents_kind_check;
ALTER TABLE commercial_documents ADD CONSTRAINT commercial_documents_kind_check
 CHECK(kind IN ('SALE_INVOICE','SALE_ACT','PURCHASE_ACT','PURCHASE_GOODS'));
ALTER TABLE batches ADD UNIQUE(company_id,id);
CREATE TABLE commercial_stock_layers(
 company_id TEXT NOT NULL,document_id TEXT NOT NULL,line_key TEXT NOT NULL,batch_id TEXT PRIMARY KEY,
 original_quantity NUMERIC(20,0) NOT NULL CHECK(original_quantity>=0),
 FOREIGN KEY(company_id,document_id) REFERENCES commercial_documents(company_id,id),
 FOREIGN KEY(company_id,batch_id) REFERENCES batches(company_id,id)
);
CREATE INDEX commercial_stock_document ON commercial_stock_layers(company_id,document_id);
INSERT INTO schema_versions VALUES(25);
