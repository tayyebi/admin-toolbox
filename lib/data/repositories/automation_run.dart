import '../../core/utils/json_codec.dart';

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
