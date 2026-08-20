/// Passed to the UI when a host key needs a human decision.
class HostKeyPrompt {
  const HostKeyPrompt({
    required this.hostname,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    this.pinnedFingerprint,
  });

  final String hostname;
  final int port;
  final String keyType;
  final String fingerprint;

  /// Set when a *different* key was previously pinned — the dangerous case.
  final String? pinnedFingerprint;

  bool get isMismatch => pinnedFingerprint != null;
}

/// Returns true to accept and pin the key.
typedef HostKeyPromptCallback = Future<bool> Function(HostKeyPrompt prompt);
