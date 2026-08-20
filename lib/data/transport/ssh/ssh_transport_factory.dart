import '../../repositories/known_host_repository.dart';
import '../transport_connection_config.dart';
import '../transport_session.dart';
import '../transport_type.dart';
import 'host_key_prompt.dart';
import 'ssh_transport_session.dart';

class SshTransportFactory implements TransportFactory {
  SshTransportFactory({this.onHostKeyPrompt, KnownHostRepository? knownHosts})
      : _knownHosts = knownHosts ?? KnownHostRepository();

  final HostKeyPromptCallback? onHostKeyPrompt;
  final KnownHostRepository _knownHosts;

  @override
  TransportType get type => TransportType.ssh;

  @override
  Future<TransportSession> create(
    TransportConnectionConfig config, {
    ConnectionLogCallback? onLog,
  }) async {
    final session = SshTransportSession(
      knownHosts: _knownHosts,
      onHostKeyPrompt: onHostKeyPrompt,
      onLog: onLog,
    );
    await session.connect(config);
    return session;
  }
}
