import 'package:sqflite/sqflite.dart';

/// `ALTER TABLE ADD COLUMN` throws if the column exists, and SQLite has no
/// `IF NOT EXISTS` for it, so the table is inspected first. This keeps every
/// migration safe to re-run against a partially upgraded database.
Future<void> addColumnIfMissing(
  Database db,
  String table,
  String column,
  String definition,
) async {
  final columns = await db.rawQuery('PRAGMA table_info($table)');
  if (columns.any((row) => row['name'] == column)) return;
  await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
}
