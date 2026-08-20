/// The audit trail, local notification history, the application log, and
/// key/value settings.
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
  // Verbose, in-app diagnostic output captured from the existing
  // logInfo/logWarning/logError/logDebug call sites, so a user can view and
  // share what actually happened when debugging a connection or
  // functionality issue. Unlike the audit log, this is not tamper-evident —
  // it is ordinary diagnostic text, meant to be freely clearable.
  '''
  CREATE TABLE app_log (
    id TEXT PRIMARY KEY,
    level TEXT NOT NULL,
    message TEXT NOT NULL,
    timestamp TEXT NOT NULL
  )
  ''',
];
