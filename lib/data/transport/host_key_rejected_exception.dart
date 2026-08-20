/// Raised when a server presents a host key we do not trust.
///
/// Carrying the fingerprints lets the UI show the user exactly what changed,
/// which is the difference between a decision and a shrug.
class HostKeyRejectedException implements Exception {
  const HostKeyRejectedException({
    required this.hostname,
    required this.port,
    required this.keyType,
    required this.presentedFingerprint,
    this.pinnedFingerprint,
  });

  final String hostname;
  final int port;
  final String keyType;
  final String presentedFingerprint;

  /// Null when the host was simply unknown rather than mismatched.
  final String? pinnedFingerprint;

  bool get isMismatch => pinnedFingerprint != null;

  @override
  String toString() {
    if (isMismatch) {
      return 'Host key for $hostname:$port has CHANGED. '
          'Expected $pinnedFingerprint but the server presented '
          '$presentedFingerprint.';
    }
    return 'Host key for $hostname:$port is not trusted yet '
        '($presentedFingerprint).';
  }
}
