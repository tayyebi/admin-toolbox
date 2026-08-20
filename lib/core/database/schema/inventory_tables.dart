/// Hosts, how they are grouped, and the server keys pinned against them.
const inventoryTables = <String>[
  '''
  CREATE TABLE hosts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    hostname TEXT NOT NULL,
    port INTEGER NOT NULL DEFAULT 22,
    username TEXT NOT NULL DEFAULT 'root',
    group_id TEXT,
    identity_id TEXT,
    connection_type TEXT NOT NULL DEFAULT 'ssh',
    tags TEXT,
    notes TEXT,
    favorite INTEGER NOT NULL DEFAULT 0,
    metadata TEXT,
    status TEXT NOT NULL DEFAULT 'unknown',
    last_seen TEXT,
    monitoring_paused INTEGER NOT NULL DEFAULT 0,
    connect_timeout_seconds INTEGER NOT NULL DEFAULT 30,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id TEXT,
    description TEXT,
    color TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (parent_id) REFERENCES groups(id) ON DELETE SET NULL
  )
  ''',
  // Host key pinning. A row appears on first connect (trust on first use); a
  // later mismatch means the server key changed and the connection is refused
  // until the user resolves it.
  '''
  CREATE TABLE known_hosts (
    id TEXT PRIMARY KEY,
    hostname TEXT NOT NULL,
    port INTEGER NOT NULL DEFAULT 22,
    key_type TEXT NOT NULL,
    fingerprint TEXT NOT NULL,
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    UNIQUE (hostname, port)
  )
  ''',
];
