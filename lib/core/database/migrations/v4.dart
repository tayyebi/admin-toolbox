import 'package:sqflite/sqflite.dart';

import 'add_column.dart';

/// Moves `username` off the vault identity and onto the host.
///
/// The same key or password is routinely reused under different usernames on
/// different targets, so the username is a property of what you are connecting
/// to, not of the credential you connect with.
Future<void> migrateToV4(Database db) async {
  await addColumnIfMissing(db, 'hosts', 'username', "TEXT NOT NULL DEFAULT 'root'");

  // Carry each host's existing username forward from the identity it was
  // using, so nothing silently reverts to 'root' on upgrade.
  await db.execute('''
    UPDATE hosts
    SET username = (
      SELECT username FROM identities WHERE identities.id = hosts.identity_id
    )
    WHERE identity_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM identities
        WHERE identities.id = hosts.identity_id AND identities.username IS NOT NULL
      )
  ''');

  await _dropIdentityUsername(db);
}

/// SQLite has no DROP COLUMN before 3.35 and the bundled sqflite engine cannot
/// be assumed to support it, so the table is rebuilt without `username`.
Future<void> _dropIdentityUsername(Database db) async {
  const columns = '''
    id, name, type, password, private_key, passphrase, certificate,
    key_type, public_key, fingerprint, comment, key_bits, last_used_at,
    crypto_version, created_at, updated_at
  ''';

  await db.execute('''
    CREATE TABLE identities_new (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'password',
      password TEXT,
      private_key TEXT,
      passphrase TEXT,
      certificate TEXT,
      key_type TEXT,
      public_key TEXT,
      fingerprint TEXT,
      comment TEXT,
      key_bits INTEGER,
      last_used_at TEXT,
      crypto_version INTEGER NOT NULL DEFAULT 2,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'INSERT INTO identities_new ($columns) SELECT $columns FROM identities',
  );
  await db.execute('DROP TABLE identities');
  await db.execute('ALTER TABLE identities_new RENAME TO identities');
}
