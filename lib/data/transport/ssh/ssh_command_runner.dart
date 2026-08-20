import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import '../../../core/utils/logger.dart';
import '../command_result.dart';

/// Runs one-shot commands over an established SSH connection.
class SshCommandRunner {
  const SshCommandRunner(this._client, {this.onLog});

  final SSHClient _client;
  final void Function(String message)? onLog;

  static const defaultTimeout = Duration(seconds: 30);

  Future<CommandResult> execute(String command, {Duration? timeout}) async {
    final limit = timeout ?? defaultTimeout;
    final stopwatch = Stopwatch()..start();

    onLog?.call('Running: $command');
    try {
      final result = await _runToCompletion(command).timeout(limit);
      stopwatch.stop();
      onLog?.call(
        'Command finished in ${stopwatch.elapsedMilliseconds} ms (exit ${result.exitCode})',
      );
      return CommandResult(
        exitCode: result.exitCode,
        stdout: result.stdout,
        stderr: result.stderr,
        duration: stopwatch.elapsed,
      );
    } on TimeoutException {
      stopwatch.stop();
      logWarning('Command timed out after ${limit.inSeconds}s: $command');
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Command timed out after ${limit.inSeconds}s',
        duration: stopwatch.elapsed,
        timedOut: true,
      );
    } catch (e) {
      stopwatch.stop();
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: '$e',
        duration: stopwatch.elapsed,
      );
    }
  }

  Future<({int exitCode, String stdout, String stderr})> _runToCompletion(String command) async {
    final session = await _client.execute(command);

    final stdout = <int>[];
    final stderr = <int>[];

    await Future.wait([
      session.stdout.forEach(stdout.addAll),
      session.stderr.forEach(stderr.addAll),
      session.done,
    ]);

    return (
      exitCode: session.exitCode ?? -1,
      stdout: _decode(stdout),
      stderr: _decode(stderr),
    );
  }

  /// Remote output is not guaranteed to be valid UTF-8 — a truncated multibyte
  /// sequence or binary output must not blow up a metric collector.
  static String _decode(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);
}
