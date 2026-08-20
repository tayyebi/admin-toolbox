import 'package:dartssh2/dartssh2.dart';

import '../../../core/utils/logger.dart';
import '../../repositories/known_host_repository.dart';
import '../command_result.dart';
import '../shell_session.dart';
import '../transport_connection_config.dart';
import '../transport_session.dart';
import '../transport_type.dart';
import 'host_key_prompt.dart';
import 'ssh_command_runner.dart';
import 'ssh_connection.dart';
import 'ssh_connector.dart';
import 'ssh_file_delegation.dart';
import 'ssh_file_operations.dart';
import 'ssh_shell_session.dart';

/// One SSH connection, presented as the app's transport contract. Opening,
/// commands and SFTP are each delegated; this type owns only the connection's
/// lifetime.
class SshTransportSession with SshFileDelegation implements TransportSession {
  SshTransportSession({
    KnownHostRepository? knownHosts,
    this.onHostKeyPrompt,
    this.onLog,
  }) : _knownHosts = knownHosts ?? KnownHostRepository();

  final KnownHostRepository _knownHosts;
  final HostKeyPromptCallback? onHostKeyPrompt;
  final void Function(String message)? onLog;

  SshConnection? _connection;
  bool _connected = false;

  @override
  SshFileOperations? files;

  @override
  TransportType get type => TransportType.ssh;

  @override
  bool get isConnected => _connected && _connection != null;

  void _log(String message) {
    logInfo(message);
    onLog?.call(message);
  }

  Future<void> connect(TransportConnectionConfig config) async {
    _log('Connecting to ${config.username}@${config.host}:${config.port}');

    final connector = SshConnector(
      knownHosts: _knownHosts,
      onPrompt: onHostKeyPrompt,
      onLog: _log,
    );

    try {
      final connection = await connector.connect(config);
      _connection = connection;
      files = SshFileOperations(connection.sftp);
      _connected = true;
      _log('Connected to ${config.host}:${config.port}');
    } catch (e, stack) {
      _connected = false;
      _log('Connection failed: $e');
      logError('SSH connection to ${config.host}:${config.port} failed', e, stack);
      rethrow;
    }
  }

  SshConnection get _live {
    final connection = _connection;
    if (connection == null || !_connected) {
      throw StateError('SSH session is not connected');
    }
    return connection;
  }

  @override
  Future<CommandResult> execute(String command, {Duration? timeout}) =>
      SshCommandRunner(_live.client, onLog: _log).execute(command, timeout: timeout);

  @override
  Future<ShellSession> openShell({int columns = 80, int rows = 24}) async {
    final session = await _live.client.shell(
      pty: SSHPtyConfig(type: 'xterm-256color', width: columns, height: rows),
    );
    return SshShellSession(session);
  }

  @override
  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
    files = null;
    _connected = false;
    _log('SSH session disconnected');
  }
}
