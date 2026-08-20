import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../models/alert.dart';

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
