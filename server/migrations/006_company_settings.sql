CREATE TABLE company_settings (
 company_id TEXT PRIMARY KEY REFERENCES companies(id),
 legal_name TEXT NOT NULL,
 identifier TEXT CHECK(identifier IS NULL OR identifier ~ '^[0-9]{12}$'),
 legal_form TEXT CHECK(legal_form IN ('TOO','IP')),
 tax_regime TEXT CHECK(tax_regime IN ('GENERAL','SIMPLIFIED')),
 vat_registered BOOLEAN NOT NULL DEFAULT FALSE,
 version INTEGER NOT NULL CHECK(version > 0)
);
INSERT INTO schema_versions VALUES(7);
