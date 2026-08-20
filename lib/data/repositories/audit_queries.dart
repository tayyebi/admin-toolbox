import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database/database.dart';
import '../models/audit_entry.dart';
import 'audit_repository.dart';

extension AuditQueries on AuditRepository {
  Future<List<AuditEntry>> getAll({int limit = 200, String? hostId, String? entityType}) async {
    final db = await AppDatabase.instance.database;

    final clauses = <String>[];
    final args = <Object?>[];
    if (hostId != null) {
      clauses.add('host_id = ?');
      args.add(hostId);
    }
    if (entityType != null) {
      clauses.add('entity_type = ?');
      args.add(entityType);
    }

    final maps = await db.query(
      'audit_log',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map(AuditEntry.fromMap).toList();
  }

  Future<List<AuditEntry>> search(String query, {int limit = 200}) async {
    final db = await AppDatabase.instance.database;
    final pattern = '%$query%';
    final maps = await db.query(
      'audit_log',
      where: 'action LIKE ? OR details LIKE ? OR entity_type LIKE ?',
      whereArgs: [pattern, pattern, pattern],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map(AuditEntry.fromMap).toList();
  }

  Future<int> getCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM audit_log');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Walks the chain oldest to newest and reports the first break.

  Future<String> exportAsJsonl({int limit = 5000}) async {
    final entries = await getAll(limit: limit);
    return entries.reversed.map((e) => jsonEncode(e.toMap())).join('\n');
  }
}
