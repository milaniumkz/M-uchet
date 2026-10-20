CREATE TABLE user_commands (
 actor_id TEXT NOT NULL REFERENCES users(id),
 key TEXT NOT NULL,
 fingerprint TEXT NOT NULL,
 response TEXT NOT NULL,
 created_at TEXT NOT NULL,
 PRIMARY KEY(actor_id,key)
);
INSERT INTO schema_versions VALUES(10);
