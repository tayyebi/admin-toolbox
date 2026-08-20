import 'package:flutter/foundation.dart';

/// What we could learn about a private key the user supplied.
@immutable
class SshKeyInspection {
  const SshKeyInspection({
    required this.valid,
    required this.encrypted,
    this.algorithm,
    this.error,
  });

  /// The key parsed successfully with the passphrase supplied (if any).
  final bool valid;

  /// The PEM is passphrase-protected.
  final bool encrypted;

  /// OpenSSH algorithm name, e.g. `ssh-ed25519`.
  final String? algorithm;

  final String? error;

  bool get needsPassphrase => encrypted && !valid;
}
