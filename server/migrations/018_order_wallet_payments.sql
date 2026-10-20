ALTER TABLE orders ADD UNIQUE(company_id,id);
ALTER TABLE payments ADD FOREIGN KEY(company_id,order_id) REFERENCES orders(company_id,id);
ALTER TABLE payments ADD COLUMN wallet_id TEXT;
ALTER TABLE payments ADD COLUMN journal_id TEXT;
ALTER TABLE payments ADD COLUMN business_date DATE;
ALTER TABLE payments ADD COLUMN voided BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE payments ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE payments ADD COLUMN void_journal_id TEXT;
ALTER TABLE payments ADD FOREIGN KEY(company_id,void_journal_id) REFERENCES journal(company_id,id);
ALTER TABLE payments ADD FOREIGN KEY(company_id,wallet_id) REFERENCES wallets(company_id,id);
ALTER TABLE payments ADD FOREIGN KEY(company_id,journal_id) REFERENCES journal(company_id,id);
UPDATE payments p SET journal_id=j.id,business_date=j.business_date FROM journal j WHERE j.company_id=p.company_id AND j.description='Payment '||p.id;
INSERT INTO schema_versions VALUES(19);
CREATE TABLE order_settlement_postings(
 id BIGSERIAL PRIMARY KEY,company_id TEXT NOT NULL REFERENCES companies(id),
 order_id TEXT NOT NULL,journal_id TEXT NOT NULL,active BOOLEAN NOT NULL DEFAULT TRUE,
 FOREIGN KEY(company_id,order_id) REFERENCES orders(company_id,id),
 FOREIGN KEY(company_id,journal_id) REFERENCES journal(company_id,id)
);
INSERT INTO order_settlement_postings(company_id,order_id,journal_id)
 SELECT o.company_id,o.id,j.id FROM orders o JOIN journal j ON j.company_id=o.company_id AND j.description='Order edit '||o.id
 WHERE EXISTS(SELECT 1 FROM journal_lines l WHERE l.entry_id=j.id AND l.account='customer_advances');
CREATE TABLE order_postings(
 company_id TEXT NOT NULL,order_id TEXT NOT NULL,journal_id TEXT NOT NULL,kind TEXT NOT NULL,
 PRIMARY KEY(company_id,journal_id),
 FOREIGN KEY(company_id,order_id) REFERENCES orders(company_id,id),
 FOREIGN KEY(company_id,journal_id) REFERENCES journal(company_id,id)
);
INSERT INTO order_postings(company_id,order_id,journal_id,kind)
 SELECT o.company_id,o.id,j.id,'LEGACY' FROM orders o JOIN journal j ON j.company_id=o.company_id
 AND j.description IN ('Sale '||o.id,'COGS '||o.id,'Order edit '||o.id);
