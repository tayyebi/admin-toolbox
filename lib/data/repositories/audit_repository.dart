import 'package:uuid/uuid.dart';
import '../../core/database/database.dart';
import '../models/audit_entry.dart';

class AuditRepository {
  final _uuid = const Uuid();

  Future<void> log({
    required String action,
    required String entityType,
    String? entityId,
    String? hostId,
    String? details,
    String? userId,
  }) async {
    final db = await AppDatabase.instance.database;
    final entry = AuditEntry(
      id: _uuid.v4(),
      action: action,
      entityType: entityType,
      entityId: entityId,
      hostId: hostId,
      details: details,
      userId: userId,
      timestamp: DateTime.now(),
    );
    await db.insert('audit_log', entry.toMap());
  }

  Future<List<AuditEntry>> getAll({int limit = 100, String? hostId}) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'audit_log',
      where: hostId != null ? 'host_id = ?' : null,
      whereArgs: hostId != null ? [hostId] : null,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map(AuditEntry.fromMap).toList();
  }

  Future<List<AuditEntry>> search(String query, {int limit = 100}) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'audit_log',
      where: 'action LIKE ? OR details LIKE ? OR entity_type LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map(AuditEntry.fromMap).toList();
  }

  Future<int> getCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM audit_log');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
