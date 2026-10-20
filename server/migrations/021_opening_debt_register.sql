ALTER TABLE debts ADD UNIQUE(company_id,id);
ALTER TABLE debts DROP CONSTRAINT debts_check;
ALTER TABLE debts ADD CHECK(remaining>=0);
ALTER TABLE debts ADD COLUMN project_id TEXT;
ALTER TABLE debts ADD COLUMN business_date DATE;
ALTER TABLE debts ADD COLUMN status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','CANCELLED'));
ALTER TABLE debts ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE debts ADD COLUMN data JSONB NOT NULL DEFAULT '{}';
ALTER TABLE debts ADD FOREIGN KEY(company_id,project_id) REFERENCES projects(company_id,id);
ALTER TABLE debt_payments ADD UNIQUE(company_id,id);
ALTER TABLE debt_payments ADD COLUMN business_date DATE;
ALTER TABLE debt_payments ADD COLUMN journal_id TEXT;
ALTER TABLE debt_payments ADD COLUMN direction TEXT CHECK(direction IN ('IN','OUT'));
ALTER TABLE debt_payments ADD COLUMN voided BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE debt_payments ADD COLUMN void_journal_id TEXT;
ALTER TABLE debt_payments ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE debt_payments ADD FOREIGN KEY(company_id,debt_id) REFERENCES debts(company_id,id);
ALTER TABLE debt_payments ADD FOREIGN KEY(company_id,wallet_id) REFERENCES wallets(company_id,id);
ALTER TABLE debt_payments ADD FOREIGN KEY(company_id,journal_id) REFERENCES journal(company_id,id);
ALTER TABLE debt_payments ADD FOREIGN KEY(company_id,void_journal_id) REFERENCES journal(company_id,id);
CREATE TABLE debt_postings(
 company_id TEXT NOT NULL,debt_id TEXT NOT NULL,journal_id TEXT NOT NULL,
 kind TEXT NOT NULL,active BOOLEAN NOT NULL DEFAULT TRUE,payment_id TEXT,
 PRIMARY KEY(company_id,journal_id),
 FOREIGN KEY(company_id,debt_id) REFERENCES debts(company_id,id),
 FOREIGN KEY(company_id,journal_id) REFERENCES journal(company_id,id),
 FOREIGN KEY(company_id,payment_id) REFERENCES debt_payments(company_id,id)
);
WITH candidates AS (
 SELECT d.company_id,d.id AS debt_id,j.id AS journal_id,count(*) OVER(PARTITION BY d.id) AS matches
 FROM debts d JOIN journal j ON j.company_id=d.company_id AND
 (j.description='Opening debt '||d.id OR EXISTS(SELECT 1 FROM journal_history h WHERE h.entry_id=j.id AND h.snapshot->>'description'='Opening debt '||d.id))
)
INSERT INTO debt_postings(company_id,debt_id,journal_id,kind) SELECT company_id,debt_id,journal_id,'OPENING' FROM candidates WHERE matches=1;
WITH candidates AS (
 SELECT p.company_id,p.debt_id,p.id AS payment_id,j.id AS journal_id,count(*) OVER(PARTITION BY p.id) AS matches
 FROM debt_payments p JOIN journal j ON j.company_id=p.company_id AND
 (j.description='Debt payment '||p.id OR EXISTS(SELECT 1 FROM journal_history h WHERE h.entry_id=j.id AND h.snapshot->>'description'='Debt payment '||p.id))
)
INSERT INTO debt_postings(company_id,debt_id,journal_id,kind,payment_id) SELECT company_id,debt_id,journal_id,'PAYMENT',payment_id FROM candidates WHERE matches=1;
WITH RECURSIVE tracked AS (
 SELECT company_id,debt_id,journal_id,payment_id FROM debt_postings
 UNION
 SELECT t.company_id,t.debt_id,r.reversal_id,t.payment_id FROM tracked t JOIN journal_reversals r ON r.original_id=t.journal_id JOIN journal j ON j.id=r.reversal_id AND j.company_id=t.company_id
)
INSERT INTO debt_postings(company_id,debt_id,journal_id,payment_id,kind,active)
 SELECT t.company_id,t.debt_id,t.journal_id,t.payment_id,'LEGACY_REVERSAL',FALSE FROM tracked t
 WHERE NOT EXISTS(SELECT 1 FROM debt_postings p WHERE p.company_id=t.company_id AND p.journal_id=t.journal_id);
UPDATE debt_postings p SET active=FALSE WHERE p.kind='PAYMENT' AND EXISTS(SELECT 1 FROM debt_postings r WHERE r.company_id=p.company_id AND r.debt_id=p.debt_id AND r.kind='LEGACY_REVERSAL');
UPDATE debts d SET project_id=j.project_id,business_date=j.business_date FROM debt_postings p JOIN journal j ON j.id=p.journal_id WHERE p.debt_id=d.id AND p.kind='OPENING';
UPDATE debts d SET business_date=(d.created_at::timestamptz AT TIME ZONE c.timezone)::date FROM companies c WHERE d.company_id=c.id AND d.business_date IS NULL;
UPDATE debts d SET data=jsonb_build_object('counterparty',COALESCE((SELECT x.data::jsonb FROM documents x WHERE x.company_id=d.company_id AND x.kind=CASE WHEN d.type='AR' THEN 'clients' ELSE 'suppliers' END AND x.id=d.counterparty_id),jsonb_build_object('name','Контрагент удалён')),'notes','','legacyImported',true);
UPDATE debt_payments p SET journal_id=s.journal_id,business_date=j.business_date FROM debt_postings s JOIN journal j ON j.id=s.journal_id WHERE s.payment_id=p.id;
UPDATE debt_payments p SET direction=CASE WHEN d.type='AR' THEN 'IN' ELSE 'OUT' END,business_date=COALESCE(p.business_date,(p.created_at::timestamptz AT TIME ZONE c.timezone)::date) FROM debts d JOIN companies c ON c.id=d.company_id WHERE p.debt_id=d.id;
UPDATE wallet_entries e SET journal_id=p.journal_id FROM debt_payments p WHERE e.company_id=p.company_id AND e.reference_id=p.id AND e.kind='DEBT_PAYMENT' AND e.journal_id IS NULL AND p.journal_id IS NOT NULL;
ALTER TABLE debts ALTER COLUMN business_date SET NOT NULL;
ALTER TABLE debt_payments ALTER COLUMN business_date SET NOT NULL;
ALTER TABLE debt_payments ALTER COLUMN direction SET NOT NULL;
CREATE INDEX debt_posting_document ON debt_postings(company_id,debt_id,active);
CREATE INDEX debt_payment_source ON debt_payments(company_id,journal_id);
CREATE INDEX debt_payment_document_date ON debt_payments(company_id,debt_id,business_date,created_at,id);
CREATE INDEX debt_list_project_scope ON debts(company_id,scope,project_id,type,id);
INSERT INTO schema_versions VALUES(22);
