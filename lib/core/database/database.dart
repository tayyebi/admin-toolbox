import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'migrations/migrations.dart';
import 'schema/schema.dart';

export 'migrations/migrations.dart';
export 'schema/schema.dart';

/// Opens the database and owns the single connection.
///
/// The schema itself lives in `schema/`, one file per subject area, and each
/// upgrade step in `migrations/v<n>.dart`. Keeping them apart means a migration
/// stays frozen at the shape it was written for, instead of quietly drifting
/// with the current schema and writing tables from the future into an old
/// database.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  /// v2 adds the SSH key vault columns, known-hosts pinning, automation run
  /// history and the audit hash chain. v3 adds per-host monitoring pause. v4
  /// moves `username` onto the host. v5 adds a per-host connect timeout.
  static const int schemaVersion = 5;

  static Database? _db;

  /// Overridable so tests can run against an in-memory FFI database.
  static DatabaseFactory? factoryOverride;
  static String? pathOverride;

  Future<Database> get database async => _db ??= await initialize();

  Future<Database> initialize() async {
    if (_db != null) return _db!;

    final factory = factoryOverride ?? databaseFactory;
    final path = pathOverride ?? join(await factory.getDatabasesPath(), 'admin_toolbox.db');

    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) => createSchema(db),
        onUpgrade: runMigrations,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
