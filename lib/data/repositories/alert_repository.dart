import 'package:uuid/uuid.dart';
import '../../core/database/database.dart';
import '../models/alert.dart';

class AlertRepository {
  final _uuid = const Uuid();

  Future<List<Alert>> getAll({String? status, String? hostId}) async {
    final db = await AppDatabase.instance.database;
    final where = <String>[];
    final args = <dynamic>[];

    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (hostId != null) {
      where.add('host_id = ?');
      args.add(hostId);
    }

    final maps = await db.query(
      'alerts',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'triggered_at DESC',
    );
    return maps.map(Alert.fromMap).toList();
  }

  Future<Alert?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('alerts', where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isNotEmpty ? Alert.fromMap(maps.first) : null;
  }

  Future<Alert> insert(Alert alert) async {
    final db = await AppDatabase.instance.database;
    final id = alert.id.isEmpty ? _uuid.v4() : alert.id;
    final newAlert = Alert(
      id: id,
      name: alert.name,
      hostId: alert.hostId,
      ruleId: alert.ruleId,
      condition: alert.condition,
      threshold: alert.threshold,
      severity: alert.severity,
      status: alert.status,
      acknowledged: alert.acknowledged,
      silencedUntil: alert.silencedUntil,
      triggeredAt: alert.triggeredAt,
      resolvedAt: alert.resolvedAt,
      message: alert.message,
    );
    await db.insert('alerts', newAlert.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return newAlert;
  }

  Future<void> acknowledge(String id) async {
    final db = await AppDatabase.instance.database;
    await db.update('alerts', {'acknowledged': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> resolve(String id) async {
    final db = await AppDatabase.instance.database;
    await db.update('alerts', {
      'status': 'resolved',
      'resolved_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> silence(String id, Duration duration) async {
    final db = await AppDatabase.instance.database;
    final until = DateTime.now().add(duration).toIso8601String();
    await db.update('alerts', {'silenced_until': until}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getActiveCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery("SELECT COUNT(*) as count FROM alerts WHERE status = 'active'");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, int>> getSeverityCounts() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      "SELECT severity, COUNT(*) as count FROM alerts WHERE status = 'active' GROUP BY severity",
    );
    final counts = <String, int>{};
    for (final row in result) {
      counts[row['severity'] as String] = row['count'] as int;
    }
    return counts;
  }
}

class AlertRuleRepository {
  final _uuid = const Uuid();

  Future<List<AlertRule>> getAll() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('alert_rules', orderBy: 'name ASC');
    return maps.map(AlertRule.fromMap).toList();
  }

  Future<AlertRule> insert(AlertRule rule) async {
    final db = await AppDatabase.instance.database;
    final id = rule.id.isEmpty ? _uuid.v4() : rule.id;
    final newRule = AlertRule(
      id: id,
      name: rule.name,
      collectorId: rule.collectorId,
      condition: rule.condition,
      threshold: rule.threshold,
      severity: rule.severity,
      action: rule.action,
      enabled: rule.enabled,
      createdAt: rule.createdAt,
      updatedAt: rule.updatedAt,
    );
    await db.insert('alert_rules', newRule.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return newRule;
  }

  Future<void> update(AlertRule rule) async {
    final db = await AppDatabase.instance.database;
    await db.update('alert_rules', rule.toMap(), where: 'id = ?', whereArgs: [rule.id]);
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('alert_rules', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggle(String id, bool enabled) async {
    final db = await AppDatabase.instance.database;
    await db.update('alert_rules', {'enabled': enabled ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }
}
