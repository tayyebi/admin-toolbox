import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initialize();
    return _db!;
  }

  Future<Database> initialize() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'admin_toolbox.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE hosts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        hostname TEXT NOT NULL,
        port INTEGER NOT NULL DEFAULT 22,
        group_id TEXT,
        identity_id TEXT,
        connection_type TEXT NOT NULL DEFAULT 'ssh',
        tags TEXT,
        notes TEXT,
        favorite INTEGER NOT NULL DEFAULT 0,
        metadata TEXT,
        status TEXT NOT NULL DEFAULT 'unknown',
        last_seen TEXT,
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
        username TEXT NOT NULL,
        password TEXT,
        private_key TEXT,
        passphrase TEXT,
        certificate TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
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

    await db.execute('''
      CREATE TABLE audit_log (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        host_id TEXT,
        details TEXT,
        user_id TEXT,
        timestamp TEXT NOT NULL
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

    await db.execute('''
      CREATE INDEX idx_metrics_host ON metrics(host_id, collector_id, timestamp)
    ''');

    await db.execute('''
      CREATE INDEX idx_alerts_status ON alerts(status, host_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_audit_timestamp ON audit_log(timestamp)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future schema migrations here
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
