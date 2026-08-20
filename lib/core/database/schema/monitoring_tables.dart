/// Collected metrics and the rules evaluated against them.
const monitoringTables = <String>[
  '''
  CREATE TABLE metrics (
    id TEXT PRIMARY KEY,
    host_id TEXT NOT NULL,
    collector_id TEXT NOT NULL,
    value TEXT NOT NULL,
    unit TEXT,
    timestamp TEXT NOT NULL,
    FOREIGN KEY (host_id) REFERENCES hosts(id) ON DELETE CASCADE
  )
  ''',
  '''
  CREATE TABLE alerts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    host_id TEXT,
    rule_id TEXT NOT NULL,
    condition TEXT NOT NULL,
    threshold TEXT,
    severity TEXT NOT NULL DEFAULT 'warning',
    status TEXT NOT NULL DEFAULT 'active',
    acknowledged INTEGER NOT NULL DEFAULT 0,
    silenced_until TEXT,
    triggered_at TEXT NOT NULL,
    resolved_at TEXT,
    message TEXT,
    FOREIGN KEY (host_id) REFERENCES hosts(id) ON DELETE SET NULL
  )
  ''',
  '''
  CREATE TABLE alert_rules (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    collector_id TEXT NOT NULL,
    condition TEXT NOT NULL,
    threshold TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'warning',
    action TEXT,
    enabled INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  ''',
];
