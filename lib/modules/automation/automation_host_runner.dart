import '../../core/utils/logger.dart';
import '../../data/models/automation.dart';
import '../../data/models/host.dart';
import '../../data/transport/connection_manager.dart';
import 'automation_rollback.dart';
import 'cancellation_token.dart';
import 'host_run_result.dart';
import 'step_outcome.dart';
import 'step_result.dart';

/// Runs a procedure's steps against one host, rolling back on failure.
class AutomationHostRunner {
  const AutomationHostRunner(this._connections, {this.rollback = const AutomationRollback()});

  final ConnectionManager _connections;
  final AutomationRollback rollback;

  Stream<void> run({
    required Automation automation,
    required Host host,
    required HostRunResult result,
    required Map<String, String> parameters,
    required CancellationToken token,
  }) async* {
    final session = await _connections.acquire(host);
    logInfo('Running automation "${automation.name}" on ${host.hostname}'
        ' (${automation.steps.length} steps)');

    try {
      for (var index = 0; index < automation.steps.length; index++) {
        if (token.isCancelled) {
          result.error = 'Cancelled';
          logInfo('Automation "${automation.name}" cancelled on ${host.hostname}'
              ' before step ${index + 1}');
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
        logInfo('Step ${index + 1}/${automation.steps.length} on ${host.hostname}: '
            '${passed ? 'succeeded' : 'failed'} (exit ${output.exitCode})');
        yield null;

        if (!passed && !step.continueOnFailure) {
          result.error = 'Step ${index + 1} failed with exit code ${output.exitCode}';
          logWarning('Step ${index + 1} failed on ${host.hostname}; rolling back');
          await for (final _ in rollback.run(automation, session, result, parameters, index)) {
            yield null;
          }
          return;
        }
      }

      result.succeeded = true;
      logInfo('Automation "${automation.name}" succeeded on ${host.hostname}');
    } finally {
      _connections.release(host);
    }
  }
}
