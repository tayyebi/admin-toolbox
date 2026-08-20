import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database/database.dart';
import '../models/log_entry.dart';
import 'log_repository.dart';

extension LogQueries on LogRepository {
  Future<List<LogEntry>> getAll({int limit = 500}) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('app_log', orderBy: 'timestamp DESC', limit: limit);
    return maps.map(LogEntry.fromMap).toList();
  }

  Future<List<LogEntry>> search(String query, {int limit = 500}) async {
    final db = await AppDatabase.instance.database;
    final pattern = '%$query%';
    final maps = await db.query(
      'app_log',
      where: 'level LIKE ? OR message LIKE ?',
      whereArgs: [pattern, pattern],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map(LogEntry.fromMap).toList();
  }

  Future<int> getCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM app_log');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<String> exportAsJsonl({int limit = 5000}) async {
    final entries = await getAll(limit: limit);
    return entries.reversed.map((e) => jsonEncode(e.toMap())).join('\n');
  }

  Future<void> clear() async {
    final db = await AppDatabase.instance.database;
    await db.delete('app_log');
  }
}
