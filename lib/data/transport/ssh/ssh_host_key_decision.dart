import '../../repositories/known_host_repository.dart';
import '../host_key_rejected_exception.dart';
import 'host_key_prompt.dart';

/// Puts a host key that is not already trusted in front of a human, and pins
/// it when they accept.
class SshHostKeyDecision {
  SshHostKeyDecision({
    required this.hostname,
    required this.port,
    required KnownHostRepository knownHosts,
    this.onPrompt,
  }) : _knownHosts = knownHosts;

  final String hostname;
  final int port;
  final KnownHostRepository _knownHosts;
  final HostKeyPromptCallback? onPrompt;

  /// Captured so the caller can throw something specific — dartssh2 surfaces a
  /// rejected key as a generic handshake error.
  HostKeyRejectedException? rejection;

  Future<bool> ask(String keyType, String fingerprint, String? pinned) async {
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
