import '../../core/utils/logger.dart';
import '../../data/models/automation.dart';
import '../../data/models/host.dart';
import '../../data/transport/connection_manager.dart';
import 'automation_dry_run.dart';
import 'automation_host_runner.dart';
import 'automation_run_progress.dart';
import 'automation_run_recorder.dart';
import 'cancellation_token.dart';
import 'host_run_result.dart';

export 'automation_run_progress.dart';
export 'automation_run_recorder.dart';
export 'cancellation_token.dart';
export 'host_run_result.dart';
export 'step_outcome.dart';
export 'step_result.dart';

/// Runs a procedure across a set of hosts, sequentially in both directions: an
/// operator running `systemctl restart` on a fleet almost always wants to see
/// the first host succeed before touching the second.
///
/// The engine owns the order hosts are visited in. What happens *on* a host is
/// [AutomationHostRunner]'s; the durable trace is [AutomationRunRecorder]'s.
class AutomationEngine {
  AutomationEngine({AutomationRunRecorder? record, AutomationHostRunner? onHost})
      : _record = record ?? AutomationRunRecorder(),
        _onHost = onHost ?? AutomationHostRunner(ConnectionManager.instance);

  final AutomationRunRecorder _record;
  final AutomationHostRunner _onHost;
  final _dryRunner = const AutomationDryRun();

  var _token = CancellationToken();

  void cancel() => _token.cancel();

  /// Emits after every step so the UI can render progress as it happens.
  Stream<AutomationRunProgress> run({
    required Automation automation,
    required List<Host> hosts,
    Map<String, String> parameters = const {},
    bool dryRun = false,
  }) async* {
    final token = _token = CancellationToken();
    final results = [
      for (final host in hosts) HostRunResult(hostId: host.id, hostName: host.name),
    ];

    final runId = await _record.start(
      automation: automation,
      hostIds: hosts.map((h) => h.id).toList(),
      parameters: parameters,
      dryRun: dryRun,
    );

    AutomationRunProgress progress({bool finished = false}) => AutomationRunProgress(
          runId: runId,
          automation: automation,
          results: results,
          finished: finished,
        );

    yield progress();

    for (var i = 0; i < hosts.length; i++) {
      if (token.isCancelled) break;
      try {
        final steps = dryRun
            ? _dryRunner.run(automation, results[i], parameters)
            : _onHost.run(
                automation: automation,
                host: hosts[i],
                result: results[i],
                parameters: parameters,
                token: token,
              );
        await for (final _ in steps) {
          yield progress();
        }
      } catch (e, stack) {
        logError('Automation ${automation.name} failed on ${hosts[i].name}', e, stack);
        results[i]
          ..error = '$e'
          ..succeeded = false;
      }
      yield progress();
    }

    await _record.finish(
      runId: runId,
      automation: automation,
      results: results,
      hostCount: hosts.length,
      dryRun: dryRun,
      cancelled: token.isCancelled,
    );
    yield progress(finished: true);
  }
}
