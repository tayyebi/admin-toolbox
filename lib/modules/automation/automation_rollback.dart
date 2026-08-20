import '../../core/utils/logger.dart';
import '../../data/models/automation.dart';
import '../../data/transport/transport.dart';
import 'host_run_result.dart';
import 'step_outcome.dart';
import 'step_result.dart';

/// Undoes the steps that already ran, newest first.
class AutomationRollback {
  const AutomationRollback();

  /// Undoes the steps that already ran, newest first.
  ///
  /// Rollback failures are recorded but never abort the rollback: leaving the
  /// remaining compensating steps unrun would strand the host in a worse state
  /// than the one that triggered it.
  Stream<void> run(
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
