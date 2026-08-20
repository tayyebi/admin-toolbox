import 'package:dartssh2/dartssh2.dart';

import '../../repositories/known_host_repository.dart';
import '../transport_connection_config.dart';
import 'host_key_prompt.dart';
import 'ssh_connection.dart';
import 'ssh_host_key_verifier.dart';
import 'ssh_identities.dart';

/// Opens a connection: TCP, then key exchange, then authentication.
///
/// Owns the socket until it hands back a [SshConnection], so a failure part way
/// through closes what it opened rather than leaving it to the caller.
class SshConnector {
  const SshConnector({required this.knownHosts, this.onPrompt, this.onLog});

  final KnownHostRepository knownHosts;
  final HostKeyPromptCallback? onPrompt;
  final void Function(String message)? onLog;

  Future<SshConnection> connect(TransportConnectionConfig config) async {
    final verifier = SshHostKeyVerifier(
      hostname: config.host,
      port: config.port,
      knownHosts: knownHosts,
      onPrompt: onPrompt,
      onLog: onLog,
    );

    SSHSocket? socket;
    SSHClient? client;
    try {
      socket = await _openSocket(config);
      client = _buildClient(socket, config, verifier);

      onLog?.call('Authenticating as ${config.username}');
      // dartssh2 2.10 has no handshake or auth timeout of its own, so the
      // authentication phase is bounded here. Without it a server that accepts
      // the TCP connection and then stalls would hang the caller indefinitely.
      await client.authenticated.timeout(config.connectTimeout);

      return SshConnection(socket: socket, client: client);
    } catch (_) {
      client?.close();
      await socket?.close();

      // A rejected host key is a security decision, not a network fault, and
      // must not be reported as "connection failed".
      final rejection = verifier.rejection;
      if (rejection != null) {
        onLog?.call('Refused host key for ${config.host}:${config.port}');
        throw rejection;
      }
      rethrow;
    }
  }

  Future<SSHSocket> _openSocket(TransportConnectionConfig config) async {
    onLog?.call(
      'Opening TCP socket to ${config.host}:${config.port} '
      '(timeout ${config.connectTimeout.inSeconds}s)',
    );

    // SSHSocket.connect's own `timeout` only bounds the TCP handshake, not DNS
    // resolution — a hostname that resolves slowly or never leaves the caller
    // stuck well past connectTimeout with nothing to show for it.
    final socket = await SSHSocket.connect(
      config.host,
      config.port,
      timeout: config.connectTimeout,
    ).timeout(config.connectTimeout);

    onLog?.call('TCP socket open');
    return socket;
  }

  SSHClient _buildClient(
    SSHSocket socket,
    TransportConnectionConfig config,
    SshHostKeyVerifier verifier,
  ) {
    final identities = SshIdentities.forConfig(config);
    onLog?.call(SshIdentities.handshakeMessage(config, identities.length));

    return SSHClient(
      socket,
      username: config.username,
      identities: identities,
      onPasswordRequest: SshIdentities.passwordRequest(config),
      onVerifyHostKey: verifier.verify,
    );
  }
}
