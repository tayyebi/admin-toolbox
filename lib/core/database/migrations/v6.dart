import 'package:sqflite/sqflite.dart';

/// Adds the persisted application log — verbose, in-app diagnostic output
/// captured from the existing logInfo/logWarning/logError/logDebug call
/// sites, for viewing and sharing when debugging a connection or
/// functionality issue in the field.
Future<void> migrateToV6(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS app_log (
      id TEXT PRIMARY KEY,
      level TEXT NOT NULL,
      message TEXT NOT NULL,
      timestamp TEXT NOT NULL
    )
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_app_log_timestamp ON app_log(timestamp)');
}
