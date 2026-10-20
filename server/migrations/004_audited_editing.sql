-- The owner explicitly requested editing posted records and closed periods.
-- Replace edit bans with persistent revisions and deferred balance validation.
DROP TRIGGER immutable_journal ON journal;
DROP TRIGGER immutable_journal_lines ON journal_lines;
DROP TRIGGER immutable_line_insert ON journal_lines;
DROP FUNCTION immutable_journal();
DROP FUNCTION immutable_line_insert();
CREATE TABLE journal_history(
  revision BIGSERIAL PRIMARY KEY,
  entry_id TEXT NOT NULL REFERENCES journal(id),
  snapshot JSONB NOT NULL,
  actor_id TEXT,
  reason TEXT,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
CREATE FUNCTION record_journal_revision() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO journal_history(entry_id,snapshot,actor_id,reason)
    VALUES(OLD.id,to_jsonb(OLD),current_setting('app.actor_id',true),current_setting('app.edit_reason',true));
  RETURN NEW;
END;
$$;
CREATE TRIGGER journal_revision BEFORE UPDATE ON journal
  FOR EACH ROW EXECUTE FUNCTION record_journal_revision();
DROP TRIGGER balanced_journal ON journal;
CREATE CONSTRAINT TRIGGER balanced_journal AFTER INSERT OR UPDATE ON journal
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION assert_journal_balance();
CREATE FUNCTION assert_line_balance() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE target_id TEXT; debits NUMERIC; credits NUMERIC; line_count INTEGER;
BEGIN
  target_id := CASE WHEN TG_OP='DELETE' THEN OLD.entry_id ELSE NEW.entry_id END;
  IF EXISTS(SELECT 1 FROM journal WHERE id=target_id) THEN
    SELECT SUM(debit),SUM(credit),COUNT(*) INTO debits,credits,line_count FROM journal_lines WHERE entry_id=target_id;
    IF line_count<2 OR debits<>credits THEN
      RAISE EXCEPTION 'Unbalanced journal entry' USING ERRCODE='23514';
    END IF;
  END IF;
  RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER balanced_journal_lines AFTER INSERT OR UPDATE OR DELETE ON journal_lines
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION assert_line_balance();
INSERT INTO schema_versions VALUES(5);
CREATE TABLE shipment_allocations(
  order_id TEXT NOT NULL REFERENCES orders(id),
  batch_id TEXT NOT NULL REFERENCES batches(id),
  quantity NUMERIC(20,0) NOT NULL CHECK(quantity>0),
  unit_cost NUMERIC(20,0) NOT NULL CHECK(unit_cost>=0),
  PRIMARY KEY(order_id,batch_id)
);
CREATE TABLE entity_history(
  revision BIGSERIAL PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
  kind TEXT NOT NULL, entity_id TEXT NOT NULL, snapshot JSONB NOT NULL,
  actor_id TEXT NOT NULL REFERENCES users(id), changed_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
