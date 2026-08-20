import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/utils/json_codec.dart';
import '../models/automation.dart';
import 'automation_run.dart';

export 'automation_run.dart';

class AutomationRunRepository {
  final _uuid = const Uuid();

  Future<String> start({
    required Automation automation,
    required List<String> hostIds,
    required Map<String, String> parameters,
    required bool dryRun,
  }) async {
    final db = await AppDatabase.instance.database;
    final id = _uuid.v4();

    await db.insert('automation_runs', {
      'id': id,
      'automation_id': automation.id,
      'automation_name': automation.name,
      'host_ids': encodeStringList(hostIds),
      'parameters': encodeStringMap(parameters),
      'status': 'running',
      'dry_run': dryRun ? 1 : 0,
      'results': '',
      'started_at': DateTime.now().toIso8601String(),
    });

    return id;
  }

  /// [results] arrives already reduced to JSON-safe maps, so the data layer
  /// does not have to import the engine's types — which would make the
  /// dependency point the wrong way, and form a cycle.
  Future<void> finish({
    required String runId,
    required String status,
    required List<Map<String, dynamic>> results,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'automation_runs',
      {
        'status': status,
        'results': encodeObjectList(results),
        'finished_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [runId],
    );
  }

  Future<List<AutomationRun>> getAll({String? automationId, int limit = 50}) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'automation_runs',
      where: automationId != null ? 'automation_id = ?' : null,
      whereArgs: automationId != null ? [automationId] : null,
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return maps.map(AutomationRun.fromMap).toList();
  }

  Future<AutomationRun?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('automation_runs', where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isEmpty ? null : AutomationRun.fromMap(maps.first);
  }

  /// Marks runs left `running` by a crash or a force-quit, so the history does
  /// not show a run that has been "in progress" for three weeks.
  Future<void> reconcileOrphans() async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'automation_runs',
      {'status': 'interrupted', 'finished_at': DateTime.now().toIso8601String()},
      where: 'status = ?',
      whereArgs: ['running'],
    );
  }
}
