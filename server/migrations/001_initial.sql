  
    CREATE TABLE IF NOT EXISTS schema_versions(version INTEGER PRIMARY KEY);
    CREATE TABLE IF NOT EXISTS users(
      id TEXT PRIMARY KEY, login TEXT NOT NULL UNIQUE, password TEXT NOT NULL,
      name TEXT NOT NULL, created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS sessions(
      token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id),
      expires_at NUMERIC(16,0) NOT NULL);
    CREATE INDEX IF NOT EXISTS sessions_user ON sessions(user_id);
    CREATE TABLE IF NOT EXISTS companies(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, currency TEXT NOT NULL,
      created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS memberships(
      company_id TEXT NOT NULL REFERENCES companies(id),
      user_id TEXT NOT NULL REFERENCES users(id),
      role TEXT NOT NULL CHECK(role IN ('owner','member')),
      permissions TEXT NOT NULL DEFAULT '[]', PRIMARY KEY(company_id,user_id));
    CREATE TABLE IF NOT EXISTS documents(
      company_id TEXT NOT NULL REFERENCES companies(id), kind TEXT NOT NULL,
      id TEXT NOT NULL, data TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      PRIMARY KEY(company_id,kind,id));
    CREATE TABLE IF NOT EXISTS batches(
      id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
      product_id TEXT NOT NULL, warehouse_id TEXT NOT NULL, scope TEXT NOT NULL,
      quantity NUMERIC(20,0) NOT NULL CHECK(quantity>=0),
      reserved NUMERIC(20,0) NOT NULL DEFAULT 0 CHECK(reserved>=0 AND reserved<=quantity),
      unit_cost NUMERIC(20,0) NOT NULL CHECK(unit_cost>=0), created_at TEXT NOT NULL, received_sequence BIGSERIAL UNIQUE);
    CREATE INDEX IF NOT EXISTS batches_stock ON batches(company_id,product_id,warehouse_id,scope);
    CREATE TABLE IF NOT EXISTS orders(
      id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
      status TEXT NOT NULL, data TEXT NOT NULL, created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS reservations(
      order_id TEXT NOT NULL REFERENCES orders(id), batch_id TEXT NOT NULL REFERENCES batches(id),
      quantity NUMERIC(20,0) NOT NULL CHECK(quantity>0), PRIMARY KEY(order_id,batch_id));
    CREATE TABLE IF NOT EXISTS journal(
      id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
      scope TEXT NOT NULL, currency TEXT NOT NULL, description TEXT NOT NULL,
      lines TEXT NOT NULL, created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS payments(
      id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
      order_id TEXT NOT NULL REFERENCES orders(id), amount NUMERIC(20,0) NOT NULL CHECK(amount>0),
      created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS files(
      id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id),
      name TEXT NOT NULL, mime TEXT NOT NULL, size INTEGER NOT NULL, created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS audit(
      sequence BIGSERIAL PRIMARY KEY, company_id TEXT NOT NULL,
      actor_id TEXT NOT NULL, action TEXT NOT NULL, resource_id TEXT NOT NULL,
      created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS idempotency(
      company_id TEXT NOT NULL, actor_id TEXT NOT NULL, key TEXT NOT NULL,
      fingerprint TEXT NOT NULL, response TEXT NOT NULL,
      PRIMARY KEY(company_id,actor_id,key));
    INSERT INTO schema_versions VALUES(1) ON CONFLICT DO NOTHING;

      CREATE TABLE wallets(id TEXT PRIMARY KEY,company_id TEXT NOT NULL REFERENCES companies(id),
        name TEXT NOT NULL,scope TEXT NOT NULL,balance NUMERIC(20,0) NOT NULL DEFAULT 0 CHECK(balance>=0));
      CREATE TABLE wallet_entries(id TEXT PRIMARY KEY,company_id TEXT NOT NULL REFERENCES companies(id),
        wallet_id TEXT NOT NULL REFERENCES wallets(id),amount NUMERIC(20,0) NOT NULL,kind TEXT NOT NULL,
        reference_id TEXT,created_at TEXT NOT NULL);
      CREATE TABLE movements(id TEXT PRIMARY KEY,company_id TEXT NOT NULL REFERENCES companies(id),
        kind TEXT NOT NULL,data TEXT NOT NULL,created_at TEXT NOT NULL);
      CREATE TABLE debts(id TEXT PRIMARY KEY,company_id TEXT NOT NULL REFERENCES companies(id),
        type TEXT NOT NULL CHECK(type IN ('AR','AP')),counterparty_id TEXT NOT NULL,
        total NUMERIC(20,0) NOT NULL CHECK(total>0),remaining NUMERIC(20,0) NOT NULL CHECK(remaining>=0 AND remaining<=total),
        scope TEXT NOT NULL,due_date TEXT,created_at TEXT NOT NULL);
      CREATE TABLE debt_payments(id TEXT PRIMARY KEY,company_id TEXT NOT NULL REFERENCES companies(id),
        debt_id TEXT NOT NULL REFERENCES debts(id),wallet_id TEXT NOT NULL REFERENCES wallets(id),
        amount NUMERIC(20,0) NOT NULL CHECK(amount>0),created_at TEXT NOT NULL);
      CREATE TABLE cash_shifts(id TEXT PRIMARY KEY,company_id TEXT NOT NULL REFERENCES companies(id),
        wallet_id TEXT NOT NULL REFERENCES wallets(id),user_id TEXT NOT NULL REFERENCES users(id),
        opening NUMERIC(20,0) NOT NULL,closing NUMERIC(20,0),status TEXT NOT NULL,opened_at TEXT NOT NULL,closed_at TEXT);
      CREATE UNIQUE INDEX cash_shift_open_wallet ON cash_shifts(wallet_id) WHERE status='OPEN';
      CREATE TABLE device_commands(id TEXT PRIMARY KEY,company_id TEXT NOT NULL REFERENCES companies(id),
        device_id TEXT NOT NULL,command TEXT NOT NULL,payload TEXT NOT NULL,status TEXT NOT NULL,
        created_at TEXT NOT NULL,acknowledged_at TEXT);
      CREATE TABLE journal_reversals(original_id TEXT PRIMARY KEY REFERENCES journal(id),
        reversal_id TEXT NOT NULL UNIQUE REFERENCES journal(id));
      INSERT INTO schema_versions VALUES(2);
    