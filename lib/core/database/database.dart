import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/logger.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  /// v1 → v2 adds the SSH key vault columns, known-hosts pinning, automation
  /// run history, and the audit hash chain. v2 → v3 adds per-host monitoring
  /// pause. v3 → v4 moves `username` off the vault identity and onto the
  /// host: the same key or password can be reused under different usernames
  /// on different targets, so it is a target property, not a credential one.
  static const int schemaVersion = 4;

  static Database? _db;

  /// Overridable so tests can run against an in-memory FFI database.
  static DatabaseFactory? factoryOverride;
  static String? pathOverride;

  Future<Database> get database async {
    return _db ??= await initialize();
  }

  Future<Database> initialize() async {
    if (_db != null) return _db!;

    final factory = factoryOverride ?? databaseFactory;
    final path = pathOverride ?? join(await factory.getDatabasesPath(), 'admin_toolbox.db');

    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
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
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
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
    ''');

    await db.execute('''
      CREATE TABLE identities (
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

    // Host key pinning. A row appears on first connect (trust on first use);
    // a later mismatch means the server key changed and the connection is
    // refused until the user resolves it.
    await db.execute('''
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
    ''');

    await db.execute('''
      CREATE TABLE metrics (
        id TEXT PRIMARY KEY,
        host_id TEXT NOT NULL,
        collector_id TEXT NOT NULL,
        value TEXT NOT NULL,
        unit TEXT,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (host_id) REFERENCES hosts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
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
    ''');

    await db.execute('''
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
    ''');

    await db.execute('''
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
    ''');

    await db.execute('''
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
    ''');

    await db.execute('''
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
    ''');

    await db.execute('''
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
    ''');

    // `prev_hash`/`entry_hash` chain each record to the one before it, so a
    // deleted or edited row breaks verification. That is what makes the log
    // tamper-evident rather than merely append-only by convention.
    await db.execute('''
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
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_metrics_host ON metrics(host_id, collector_id, timestamp)',
      'CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON metrics(timestamp)',
      'CREATE INDEX IF NOT EXISTS idx_alerts_status ON alerts(status, host_id)',
      'CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp)',
      'CREATE INDEX IF NOT EXISTS idx_hosts_group ON hosts(group_id)',
      'CREATE INDEX IF NOT EXISTS idx_hosts_identity ON hosts(identity_id)',
      'CREATE INDEX IF NOT EXISTS idx_known_hosts_lookup ON known_hosts(hostname, port)',
      'CREATE INDEX IF NOT EXISTS idx_runs_automation ON automation_runs(automation_id, started_at)',
    ];
    for (final statement in statements) {
      await db.execute(statement);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    logInfo('Migrating database from v$oldVersion to v$newVersion');

    if (oldVersion < 2) {
      // Existing identity rows were sealed with the v1 AES-CBC scheme. They
      // keep crypto_version = 1 and are re-encrypted lazily on first unlock.
      const identityColumns = {
        'key_type': 'TEXT',
        'public_key': 'TEXT',
        'fingerprint': 'TEXT',
        'comment': 'TEXT',
        'key_bits': 'INTEGER',
        'last_used_at': 'TEXT',
        'crypto_version': 'INTEGER NOT NULL DEFAULT 1',
      };
      for (final entry in identityColumns.entries) {
        await _addColumnIfMissing(db, 'identities', entry.key, entry.value);
      }

      await _addColumnIfMissing(db, 'audit_log', 'prev_hash', 'TEXT');
      await _addColumnIfMissing(db, 'audit_log', 'entry_hash', 'TEXT');

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

      await _createIndexes(db);
    }

    if (oldVersion < 3) {
      await _addColumnIfMissing(db, 'hosts', 'monitoring_paused', 'INTEGER NOT NULL DEFAULT 0');
    }

    if (oldVersion < 4) {
      await _addColumnIfMissing(db, 'hosts', 'username', "TEXT NOT NULL DEFAULT 'root'");

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

      // SQLite has no DROP COLUMN before 3.35 and the bundled sqflite engine
      // cannot be assumed to support it, so the table is rebuilt without
      // `username` instead.
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
      await db.execute('''
        INSERT INTO identities_new (
          id, name, type, password, private_key, passphrase, certificate,
          key_type, public_key, fingerprint, comment, key_bits, last_used_at,
          crypto_version, created_at, updated_at
        )
        SELECT
          id, name, type, password, private_key, passphrase, certificate,
          key_type, public_key, fingerprint, comment, key_bits, last_used_at,
          crypto_version, created_at, updated_at
        FROM identities
      ''');
      await db.execute('DROP TABLE identities');
      await db.execute('ALTER TABLE identities_new RENAME TO identities');
    }
  }

  /// `ALTER TABLE ADD COLUMN` throws if the column exists, and SQLite has no
  /// `IF NOT EXISTS` for it, so the table is inspected first. This keeps the
  /// migration safe to re-run against a partially upgraded database.
  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
