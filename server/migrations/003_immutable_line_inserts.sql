ALTER TABLE journal ADD COLUMN posting_txid BIGINT NOT NULL DEFAULT txid_current();
CREATE FUNCTION immutable_line_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM journal WHERE id=NEW.entry_id AND posting_txid=txid_current()) THEN
    RAISE EXCEPTION 'Cannot append to an already posted journal' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER immutable_line_insert BEFORE INSERT ON journal_lines
  FOR EACH ROW EXECUTE FUNCTION immutable_line_insert();
INSERT INTO schema_versions VALUES(4);
