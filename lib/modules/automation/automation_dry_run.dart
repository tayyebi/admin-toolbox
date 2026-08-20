import '../../data/models/automation.dart';
import 'host_run_result.dart';
import 'step_outcome.dart';
import 'step_result.dart';

/// Resolves every variable and shows the exact command line without opening a
/// connection — the cheapest way to catch a bad substitution before it reaches
/// a production box.
class AutomationDryRun {
  const AutomationDryRun();

  Stream<void> run(
    Automation automation,
    HostRunResult result,
    Map<String, String> parameters,
  ) async* {
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
  }
}
