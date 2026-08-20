import 'dart:convert';
import 'dart:typed_data';

import '../../repositories/known_host_repository.dart';
import '../host_key_rejected_exception.dart';
import 'host_key_prompt.dart';

/// Trust on first use, with a hard stop on change.
///
/// dartssh2 hands us the OpenSSH-style `SHA256:…` fingerprint already
/// formatted, so what is compared and what the user is shown are the same
/// string they would get from `ssh-keygen -lf`.
class SshHostKeyVerifier {
  SshHostKeyVerifier({
    required this.hostname,
    required this.port,
    required KnownHostRepository knownHosts,
    this.onPrompt,
    this.onLog,
  }) : _knownHosts = knownHosts;

  final String hostname;
  final int port;
  final KnownHostRepository _knownHosts;
  final HostKeyPromptCallback? onPrompt;
  final void Function(String message)? onLog;

  /// Captured so the caller can throw something specific — dartssh2 surfaces a
  /// rejected key as a generic handshake error.
  HostKeyRejectedException? rejection;

  Future<bool> verify(String keyType, Uint8List fingerprintBytes) async {
    final fingerprint = utf8.decode(fingerprintBytes);
    onLog?.call('Server presented $keyType host key ($fingerprint)');

    final check = await _knownHosts.verify(hostname, port, fingerprint);

    switch (check.verdict) {
      case HostKeyVerdict.trusted:
        onLog?.call('Host key matches the pinned fingerprint');
        return true;

      case HostKeyVerdict.unknown:
        onLog?.call('Host key is not yet trusted — asking for a decision');
        return _decide(keyType, fingerprint, null);

      case HostKeyVerdict.mismatch:
        onLog?.call(
          'Host key MISMATCH — pinned ${check.pinned?.fingerprint}, got $fingerprint',
        );
        // The pinned key changed. Either a rebuilt server or an interception;
        // never accepted without an explicit override.
        return _decide(keyType, fingerprint, check.pinned?.fingerprint);
    }
  }

  Future<bool> _decide(String keyType, String fingerprint, String? pinned) async {
    final reject = HostKeyRejectedException(
      hostname: hostname,
      port: port,
      keyType: keyType,
      presentedFingerprint: fingerprint,
      pinnedFingerprint: pinned,
    );

    final prompt = onPrompt;
    if (prompt == null) {
      // No one to ask — refuse rather than trusting silently.
      rejection = reject;
      return false;
    }

    final accepted = await prompt(
      HostKeyPrompt(
        hostname: hostname,
        port: port,
        keyType: keyType,
        fingerprint: fingerprint,
        pinnedFingerprint: pinned,
      ),
    );
    if (!accepted) {
      rejection = reject;
      return false;
    }

    await _knownHosts.trust(
      hostname: hostname,
      port: port,
      keyType: keyType,
      fingerprint: fingerprint,
    );
    return true;
  }
}
