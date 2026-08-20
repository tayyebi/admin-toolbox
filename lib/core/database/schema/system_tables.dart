/// The audit trail, local notification history, and key/value settings.
const systemTables = <String>[
  // `prev_hash`/`entry_hash` chain each record to the one before it, so a
  // deleted or edited row breaks verification. That is what makes the log
  // tamper-evident rather than merely append-only by convention.
  '''
  CREATE TABLE audit_log (
    id TEXT PRIMARY KEY,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT,
    host_id TEXT,
    details TEXT,
    user_id TEXT,
    timestamp TEXT NOT NULL,
    prev_hash TEXT,
    entry_hash TEXT
  )
  ''',
  '''
  CREATE TABLE notifications (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    read INTEGER NOT NULL DEFAULT 0,
    timestamp TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
  ''',
];
