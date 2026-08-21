import 'dart:typed_data';

import '../../repositories/known_host_repository.dart';
import '../host_key_rejected_exception.dart';
import 'host_key_prompt.dart';
import 'ssh_fingerprint.dart';
import 'ssh_host_key_decision.dart';

/// Trust on first use, with a hard stop on change.
///
/// What is compared and what the user is shown are the same string;
/// [SshFingerprint] decides what that string looks like, because dartssh2 does
/// not hand over one consistent format across versions.
class SshHostKeyVerifier {
  SshHostKeyVerifier({
    required this.hostname,
    required this.port,
    required KnownHostRepository knownHosts,
    HostKeyPromptCallback? onPrompt,
    this.onLog,
  })  : _knownHosts = knownHosts,
        _decision = SshHostKeyDecision(
          hostname: hostname,
          port: port,
          knownHosts: knownHosts,
          onPrompt: onPrompt,
        );

  final String hostname;
  final int port;
  final KnownHostRepository _knownHosts;
  final SshHostKeyDecision _decision;
  final void Function(String message)? onLog;

  /// Set when the key was refused rather than merely unverifiable.
  HostKeyRejectedException? get rejection => _decision.rejection;

  /// Nothing may be thrown out of here. dartssh2 2.11 casts whatever escapes
  /// this callback to `SSHError`, and when that cast fails the handshake is
  /// neither completed nor failed — the connection then hangs until the
  /// caller's timeout, blaming the network for a local fault.
  Future<bool> verify(String keyType, Uint8List fingerprintBytes) async {
    try {
      return await _check(keyType, SshFingerprint.format(fingerprintBytes));
    } catch (e) {
      onLog?.call('Host key check failed: $e');
      return false;
    }
  }

  Future<bool> _check(String keyType, String fingerprint) async {
    onLog?.call('Server presented $keyType host key ($fingerprint)');

    final check = await _knownHosts.verify(hostname, port, fingerprint);

    switch (check.verdict) {
      case HostKeyVerdict.trusted:
        onLog?.call('Host key matches the pinned fingerprint');
        return true;

      case HostKeyVerdict.unknown:
        onLog?.call('Host key is not yet trusted — asking for a decision');
        return _decision.ask(keyType, fingerprint, null);

      case HostKeyVerdict.mismatch:
        onLog?.call(
          'Host key MISMATCH — pinned ${check.pinned?.fingerprint}, got $fingerprint',
        );
        // The pinned key changed. Either a rebuilt server or an interception;
        // never accepted without an explicit override.
        return _decision.ask(keyType, fingerprint, check.pinned?.fingerprint);
    }
  }
}
