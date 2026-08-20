import '../../data/models/automation.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/automation_run_repository.dart';
import 'host_run_result.dart';

/// The durable trace of a run: its row in the history, and its audit entry.
class AutomationRunRecorder {
  AutomationRunRecorder({AutomationRunRepository? runs, AuditRepository? audit})
      : _runs = runs ?? AutomationRunRepository(),
        _audit = audit ?? AuditRepository();

  final AutomationRunRepository _runs;
  final AuditRepository _audit;

  Future<String> start({
    required Automation automation,
    required List<String> hostIds,
    required Map<String, String> parameters,
    required bool dryRun,
  }) =>
      _runs.start(
        automation: automation,
        hostIds: hostIds,
        parameters: parameters,
        dryRun: dryRun,
      );

  Future<void> finish({
    required String runId,
    required Automation automation,
    required List<HostRunResult> results,
    required int hostCount,
    required bool dryRun,
    required bool cancelled,
  }) async {
    final status = cancelled
        ? 'cancelled'
        : (results.every((r) => r.succeeded) ? 'succeeded' : 'failed');

    await _runs.finish(
      runId: runId,
      status: status,
      results: results.map((r) => r.toJson()).toList(),
    );
    await _audit.log(
      action: dryRun ? 'automation_dry_run' : 'automation_run',
      entityType: 'automation',
      entityId: automation.id,
      details: '${automation.name} on $hostCount host(s) → $status',
    );
  }
}
