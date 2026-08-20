import 'package:dartssh2/dartssh2.dart';

import '../../../core/crypto/ssh_key_service.dart';
import '../transport_connection_config.dart';

/// Turns a stored credential into what dartssh2 wants to authenticate with.
abstract final class SshIdentities {
  static List<SSHKeyPair> forConfig(TransportConnectionConfig config) {
    final pem = config.privateKey;
    if (pem == null || pem.isEmpty) return const [];
    return SshKeyService.instance.parse(pem, passphrase: config.passphrase);
  }

  static String Function()? passwordRequest(TransportConnectionConfig config) {
    final password = config.password;
    if (password == null || password.isEmpty) return null;
    return () => password;
  }

  static String handshakeMessage(TransportConnectionConfig config, int identityCount) {
    final key = config.privateKey;
    if (key == null || key.isEmpty) return 'Starting SSH handshake (password authentication)';
    final noun = identityCount == 1 ? 'identity' : 'identities';
    return 'Starting SSH handshake with $identityCount key $noun offered';
  }
}
