CREATE TABLE journal_lines(
  entry_id TEXT NOT NULL REFERENCES journal(id),
  position INTEGER NOT NULL CHECK(position>=0),
  account TEXT NOT NULL,
  debit NUMERIC(20,0) NOT NULL CHECK(debit>=0),
  credit NUMERIC(20,0) NOT NULL CHECK(credit>=0),
  PRIMARY KEY(entry_id,position),
  CHECK ((debit>0 AND credit=0) OR (credit>0 AND debit=0))
);
INSERT INTO journal_lines
  SELECT j.id,(line.ordinality-1)::integer,line.value->>'account',
    (line.value->>'debit')::numeric,(line.value->>'credit')::numeric
  FROM journal j CROSS JOIN LATERAL jsonb_array_elements(j.lines::jsonb) WITH ORDINALITY AS line(value,ordinality);
CREATE FUNCTION assert_journal_balance() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE debits NUMERIC; credits NUMERIC; line_count INTEGER;
BEGIN
  SELECT SUM(debit),SUM(credit),COUNT(*) INTO debits,credits,line_count FROM journal_lines WHERE entry_id=NEW.id;
  IF line_count<2 OR debits<>credits THEN
    RAISE EXCEPTION 'Unbalanced journal entry' USING ERRCODE='23514';
  END IF;
  RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER balanced_journal AFTER INSERT ON journal
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION assert_journal_balance();
CREATE FUNCTION immutable_journal() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Posted journal is immutable' USING ERRCODE='23514'; END;
$$;
CREATE TRIGGER immutable_journal BEFORE UPDATE OR DELETE ON journal FOR EACH ROW EXECUTE FUNCTION immutable_journal();
CREATE TRIGGER immutable_journal_lines BEFORE UPDATE OR DELETE ON journal_lines FOR EACH ROW EXECUTE FUNCTION immutable_journal();
ALTER TABLE companies ADD COLUMN timezone TEXT NOT NULL DEFAULT 'Asia/Almaty';
ALTER TABLE journal ADD COLUMN business_date DATE;
UPDATE journal SET business_date=created_at::timestamptz AT TIME ZONE 'Asia/Almaty';
ALTER TABLE journal ALTER COLUMN business_date SET NOT NULL;
CREATE TABLE accounting_periods(
  company_id TEXT NOT NULL REFERENCES companies(id),
  month TEXT NOT NULL CHECK(month ~ '^\d{4}-(0[1-9]|1[0-2])$'),
  status TEXT NOT NULL CHECK(status IN ('OPEN','CLOSED')),
  changed_by TEXT NOT NULL REFERENCES users(id),
  changed_at TEXT NOT NULL,
  PRIMARY KEY(company_id,month)
);
INSERT INTO schema_versions VALUES(3);
