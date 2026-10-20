ALTER TABLE wallet_entries ADD COLUMN journal_id TEXT REFERENCES journal(id);
INSERT INTO schema_versions VALUES(8);
