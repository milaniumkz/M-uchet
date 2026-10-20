-- Applied only when initializing a new empty production database volume.
-- psql reads the secret from its inherited environment, never from argv.
\getenv app_password MUCHET_APP_PASSWORD
CREATE ROLE muchet WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD :'app_password';
ALTER DATABASE muchet OWNER TO muchet;
