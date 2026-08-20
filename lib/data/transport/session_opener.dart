import '../models/host.dart';
import '../models/identity.dart';
import '../repositories/identity_repository.dart';
import 'missing_identity_exception.dart';
import 'ssh/host_key_prompt.dart';
import 'ssh/ssh_transport_factory.dart';
import 'transport_connection_config.dart';
import 'transport_session.dart';

/// Resolves a host's credential and opens a session with it.
///
/// Separated from the pool so that "which credential, and what does the
/// connection look like" stays in one place, and pooling stays about lifetime.
class SessionOpener {
  SessionOpener({IdentityRepository? identities})
      : _identities = identities ?? IdentityRepository();

  final IdentityRepository _identities;

  Future<TransportSession> open(
    Host host, {
    Duration? connectTimeout,
    HostKeyPromptCallback? onHostKeyPrompt,
  }) async {
    final identity = await _resolveIdentity(host);

    final session = await SshTransportFactory(onHostKeyPrompt: onHostKeyPrompt).create(
      TransportConnectionConfig(
        host: host.hostname,
        port: host.port,
        username: host.username,
        password: identity.password,
        privateKey: identity.privateKey,
        passphrase: identity.passphrase,
        connectTimeout: connectTimeout ?? Duration(seconds: host.connectTimeoutSeconds),
      ),
    );

    await _identities.markUsed(identity.id);
    return session;
  }

  Future<Identity> _resolveIdentity(Host host) async {
    final identityId = host.identityId;
    if (identityId == null || identityId.isEmpty) throw MissingIdentityException(host);

    final identity = await _identities.getById(identityId);
    if (identity == null) throw MissingIdentityException(host);
    return identity;
  }
}
