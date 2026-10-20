ALTER TABLE cash_shifts ADD COLUMN expected_balance NUMERIC(20,0);
ALTER TABLE cash_shifts ADD COLUMN closed_by TEXT REFERENCES users(id);
INSERT INTO schema_versions VALUES(17);
