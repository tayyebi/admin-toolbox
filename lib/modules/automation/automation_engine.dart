import 'dart:async';

import '../../core/utils/logger.dart';
import '../../data/models/automation.dart';
import '../../data/models/host.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/automation_run_repository.dart';
import '../../data/transport/connection_manager.dart';
import '../../data/transport/transport.dart';

enum StepOutcome { pending, running, succeeded, failed, skipped, rolledBack }

class StepResult {
  StepResult({
    required this.stepIndex,
    required this.command,
    this.outcome = StepOutcome.pending,
    this.exitCode,
    this.output = '',
    this.duration = Duration.zero,
  });

  final int stepIndex;
  final String command;
  StepOutcome outcome;
  int? exitCode;
  String output;
  Duration duration;

  Map<String, dynamic> toJson() => {
        'step': stepIndex,
        'command': command,
        'outcome': outcome.name,
        'exit_code': exitCode,
        'output': output,
        'duration_ms': duration.inMilliseconds,
      };
}

class HostRunResult {
  HostRunResult({required this.hostId, required this.hostName});

  final String hostId;
  final String hostName;
  final List<StepResult> steps = [];

  bool succeeded = false;
  bool rolledBack = false;
  String? error;

  Map<String, dynamic> toJson() => {
        'host_id': hostId,
        'host_name': hostName,
        'succeeded': succeeded,
        'rolled_back': rolledBack,
        'error': error,
        'steps': steps.map((s) => s.toJson()).toList(),
      };
}

/// A live view of one execution, streamed to the run screen.
class AutomationRunProgress {
  AutomationRunProgress({
    required this.runId,
    required this.automation,
    required this.results,
    this.finished = false,
  });

  final String runId;
  final Automation automation;
  final List<HostRunResult> results;
  final bool finished;

  int get succeededCount => results.where((r) => r.succeeded).length;
  int get failedCount => results.where((r) => !r.succeeded && r.error != null).length;
}

/// Runs a procedure across a set of hosts.
///
/// Sequential per host and sequential across hosts by default: an operator
/// running `systemctl restart` on a fleet almost always wants to see the first
/// host succeed before touching the second.
class AutomationEngine {
  AutomationEngine({
    ConnectionManager? connections,
    AutomationRunRepository? runs,
    AuditRepository? audit,
  })  : _connections = connections ?? ConnectionManager.instance,
        _runs = runs ?? AutomationRunRepository(),
        _audit = audit ?? AuditRepository();

  final ConnectionManager _connections;
  final AutomationRunRepository _runs;
  final AuditRepository _audit;

  bool _cancelled = false;

  void cancel() => _cancelled = true;

  /// Emits after every step so the UI can render progress as it happens.
  Stream<AutomationRunProgress> run({
    required Automation automation,
    required List<Host> hosts,
    Map<String, String> parameters = const {},
    bool dryRun = false,
  }) async* {
    _cancelled = false;

    final results = [
      for (final host in hosts) HostRunResult(hostId: host.id, hostName: host.name),
    ];

    final runId = await _runs.start(
      automation: automation,
      hostIds: hosts.map((h) => h.id).toList(),
      parameters: parameters,
      dryRun: dryRun,
    );

    yield AutomationRunProgress(runId: runId, automation: automation, results: results);

    for (var i = 0; i < hosts.length; i++) {
      if (_cancelled) break;

      final host = hosts[i];
      final result = results[i];

      try {
        await for (final _ in _runOnHost(
          automation: automation,
          host: host,
          result: result,
          parameters: parameters,
          dryRun: dryRun,
        )) {
          yield AutomationRunProgress(
            runId: runId,
            automation: automation,
            results: results,
          );
        }
      } catch (e, stack) {
        logError('Automation ${automation.name} failed on ${host.name}', e, stack);
        result.error = '$e';
        result.succeeded = false;
      }

      yield AutomationRunProgress(runId: runId, automation: automation, results: results);
    }

    final status = _cancelled
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
      details: '${automation.name} on ${hosts.length} host(s) → $status',
    );

    yield AutomationRunProgress(
      runId: runId,
      automation: automation,
      results: results,
      finished: true,
    );
  }

  Stream<void> _runOnHost({
    required Automation automation,
    required Host host,
    required HostRunResult result,
    required Map<String, String> parameters,
    required bool dryRun,
  }) async* {
    // Dry run resolves every variable and shows the exact command line without
    // opening a connection — the cheapest way to catch a bad substitution
    // before it reaches a production box.
    if (dryRun) {
      for (var index = 0; index < automation.steps.length; index++) {
        final step = automation.steps[index];
        result.steps.add(
          StepResult(
            stepIndex: index,
            command: step.interpolate(parameters),
            outcome: StepOutcome.skipped,
            output: '(dry run — not executed)',
          ),
        );
        yield null;
      }
      result.succeeded = true;
      return;
    }

    final session = await _connections.acquire(host);

    try {
      for (var index = 0; index < automation.steps.length; index++) {
        if (_cancelled) {
          result.error = 'Cancelled';
          return;
        }

        final step = automation.steps[index];
        final command = step.interpolate(parameters);

        final stepResult = StepResult(
          stepIndex: index,
          command: command,
          outcome: StepOutcome.running,
        );
        result.steps.add(stepResult);
        yield null;

        final stopwatch = Stopwatch()..start();
        final output = await session.execute(command, timeout: step.timeout);
        stopwatch.stop();

        stepResult
          ..exitCode = output.exitCode
          ..output = output.output
          ..duration = stopwatch.elapsed;

        final passed = output.exitCode == step.expectedExitCode && !output.timedOut;
        stepResult.outcome = passed ? StepOutcome.succeeded : StepOutcome.failed;
        yield null;

        if (!passed && !step.continueOnFailure) {
          result.error = 'Step ${index + 1} failed with exit code ${output.exitCode}';
          await for (final _ in _rollback(automation, session, result, parameters, index)) {
            yield null;
          }
          return;
        }
      }

      result.succeeded = true;
    } finally {
      _connections.release(host);
    }
  }

  /// Undoes the steps that already ran, newest first.
  ///
  /// Rollback failures are recorded but never abort the rollback: leaving the
  /// remaining compensating steps unrun would strand the host in a worse state
  /// than the one that triggered it.
  Stream<void> _rollback(
    Automation automation,
    TransportSession session,
    HostRunResult result,
    Map<String, String> parameters,
    int failedIndex,
  ) async* {
    final rollbackSteps = automation.rollbackSteps;
    if (rollbackSteps == null || rollbackSteps.isEmpty) return;

    logInfo('Rolling back ${automation.name} on ${result.hostName}');

    final applicable = rollbackSteps.length > failedIndex + 1
        ? rollbackSteps.sublist(0, failedIndex + 1)
        : rollbackSteps;

    for (final step in applicable.reversed) {
      final command = step.interpolate(parameters);
      final stepResult = StepResult(
        stepIndex: -1,
        command: command,
        outcome: StepOutcome.running,
      );
      result.steps.add(stepResult);
      yield null;

      try {
        final output = await session.execute(command, timeout: step.timeout);
        stepResult
          ..exitCode = output.exitCode
          ..output = output.output
          ..outcome = StepOutcome.rolledBack;
      } catch (e) {
        stepResult
          ..outcome = StepOutcome.failed
          ..output = '$e';
      }
      yield null;
    }

    result.rolledBack = true;
  }
}
