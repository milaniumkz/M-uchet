ALTER TABLE wallet_entries ADD UNIQUE(company_id,id);
ALTER TABLE bank_import_rows ADD COLUMN matched_entry_id TEXT;
ALTER TABLE bank_import_rows ADD FOREIGN KEY(company_id,matched_entry_id) REFERENCES wallet_entries(company_id,id);
CREATE UNIQUE INDEX bank_one_statement_per_wallet_entry ON bank_import_rows(company_id,matched_entry_id) WHERE matched_entry_id IS NOT NULL;
INSERT INTO schema_versions VALUES(18);
