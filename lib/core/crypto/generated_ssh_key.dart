import 'package:flutter/foundation.dart';

/// A freshly generated key pair.
@immutable
class GeneratedSshKey {
  const GeneratedSshKey({
    required this.privateKeyPem,
    required this.publicKeyLine,
    required this.fingerprint,
    required this.algorithm,
    required this.bits,
  });

  final String privateKeyPem;
  final String publicKeyLine;
  final String fingerprint;
  final String algorithm;
  final int bits;
}
