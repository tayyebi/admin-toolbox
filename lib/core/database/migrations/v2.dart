import 'package:sqflite/sqflite.dart';

import '../schema/indexes.dart';
import 'add_column.dart';

/// Adds the SSH key vault columns, known-hosts pinning, automation run
/// history, and the audit hash chain.
///
/// The table bodies here are copies rather than references to the live schema,
/// and deliberately so: a migration describes the shape of the database *at
/// this version*. If it tracked the current schema it would start writing
/// tables from the future into old databases.
Future<void> migrateToV2(Database db) async {
  const identityColumns = {
    'key_type': 'TEXT',
    'public_key': 'TEXT',
    'fingerprint': 'TEXT',
    'comment': 'TEXT',
    'key_bits': 'INTEGER',
    'last_used_at': 'TEXT',
    // Existing rows were sealed with the v1 AES-CBC scheme. They keep
    // crypto_version = 1 and are re-encrypted lazily on first unlock.
    'crypto_version': 'INTEGER NOT NULL DEFAULT 1',
  };
  for (final entry in identityColumns.entries) {
    await addColumnIfMissing(db, 'identities', entry.key, entry.value);
  }

  await addColumnIfMissing(db, 'audit_log', 'prev_hash', 'TEXT');
  await addColumnIfMissing(db, 'audit_log', 'entry_hash', 'TEXT');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS known_hosts (
      id TEXT PRIMARY KEY,
      hostname TEXT NOT NULL,
      port INTEGER NOT NULL DEFAULT 22,
      key_type TEXT NOT NULL,
      fingerprint TEXT NOT NULL,
      first_seen TEXT NOT NULL,
      last_seen TEXT NOT NULL,
      UNIQUE (hostname, port)
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS automation_runs (
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
  ''');

  for (final statement in indexStatements) {
    await db.execute(statement);
  }
}
