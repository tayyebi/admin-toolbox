import '../../data/models/automation.dart';
import 'host_run_result.dart';

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
