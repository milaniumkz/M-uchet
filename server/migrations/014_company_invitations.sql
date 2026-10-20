CREATE TABLE company_invitations(
 id TEXT PRIMARY KEY,token_hash TEXT NOT NULL UNIQUE,
 company_id TEXT NOT NULL REFERENCES companies(id),login TEXT NOT NULL,name TEXT NOT NULL,
 permissions TEXT NOT NULL,created_by TEXT NOT NULL REFERENCES users(id),
 expires_at NUMERIC(16,0) NOT NULL,accepted_by TEXT REFERENCES users(id),
 accepted_at NUMERIC(16,0),revoked BOOLEAN NOT NULL DEFAULT FALSE,created_at TEXT NOT NULL
);
CREATE INDEX company_invitations_company ON company_invitations(company_id,login);
INSERT INTO schema_versions VALUES(15);
