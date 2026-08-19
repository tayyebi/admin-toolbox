/// Incidents, saved procedures, their run history, and the command library.
const operationsTables = <String>[
  '''
  CREATE TABLE incidents (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'open',
    severity TEXT NOT NULL DEFAULT 'medium',
    affected_hosts TEXT,
    timeline TEXT,
    resolution TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    resolved_at TEXT
  )
  ''',
  '''
  CREATE TABLE automations (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    parameters TEXT,
    steps TEXT NOT NULL,
    rollback_steps TEXT,
    validation TEXT,
    output_parser TEXT,
    favorite INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE automation_runs (
    id TEXT PRIMARY KEY,
    automation_id TEXT NOT NULL,
    automation_name TEXT NOT NULL,
    host_ids TEXT NOT NULL,
    parameters TEXT,
    status TEXT NOT NULL DEFAULT 'running',
    dry_run INTEGER NOT NULL DEFAULT 0,
    results TEXT,
    started_at TEXT NOT NULL,
    finished_at TEXT
  )
  ''',
  '''
  CREATE TABLE commands (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    command TEXT NOT NULL,
    description TEXT,
    category TEXT,
    variables TEXT,
    favorite INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  ''',
];
