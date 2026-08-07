import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/utils/json_codec.dart';
import '../models/automation.dart';

/// A recorded execution of an automation.
class AutomationRun {
  const AutomationRun({
    required this.id,
    required this.automationId,
    required this.automationName,
    required this.hostIds,
    required this.parameters,
    required this.status,
    required this.dryRun,
    required this.results,
    required this.startedAt,
    this.finishedAt,
  });

  final String id;
  final String automationId;
  final String automationName;
  final List<String> hostIds;
  final Map<String, String> parameters;

  /// `running`, `succeeded`, `failed` or `cancelled`.
  final String status;

  final bool dryRun;

  /// One entry per host, as written by the engine.
  final List<Map<String, dynamic>> results;

  final DateTime startedAt;
  final DateTime? finishedAt;

  Duration? get duration => finishedAt?.difference(startedAt);

  factory AutomationRun.fromMap(Map<String, dynamic> map) => AutomationRun(
        id: map['id'] as String,
        automationId: map['automation_id'] as String,
        automationName: map['automation_name'] as String,
        hostIds: decodeStringList(map['host_ids'] as String?),
        parameters: decodeStringMap(map['parameters'] as String?),
        status: map['status'] as String? ?? 'running',
        dryRun: (map['dry_run'] as int?) == 1,
        results: decodeObjectList(map['results'] as String?),
        startedAt: DateTime.parse(map['started_at'] as String),
        finishedAt: parseDateOrNull(map['finished_at']),
      );
}

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
