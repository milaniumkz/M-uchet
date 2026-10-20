CREATE TABLE password_resets(
 token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id),
 expires_at NUMERIC(16,0) NOT NULL, used_at NUMERIC(16,0)
);
CREATE INDEX password_resets_user ON password_resets(user_id);
INSERT INTO schema_versions VALUES(12);
