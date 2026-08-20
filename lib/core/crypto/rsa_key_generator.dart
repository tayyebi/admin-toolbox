import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import 'generated_ssh_key.dart';
import 'ssh_wire.dart';

@immutable
class RsaGenerationRequest {
  const RsaGenerationRequest({required this.bits, this.comment});

  final int bits;
  final String? comment;
}

/// Top-level so [compute] can run it off the UI isolate.
///
/// RSA rather than Ed25519 because `dartssh2` exposes no key generation and
/// pure-Dart Ed25519 would mean hand-rolling the `openssh-key-v1` container;
/// RSA's PKCS#1 PEM is a format we can write correctly and verify.
GeneratedSshKey generateRsaKey(RsaGenerationRequest request) {
  final pair = _generatePair(request.bits);
  final publicKey = pair.publicKey as RSAPublicKey;
  final privateKey = pair.privateKey as RSAPrivateKey;

  final n = publicKey.modulus!;
  final e = publicKey.publicExponent!;
  final d = privateKey.privateExponent!;
  final p = privateKey.p!;
  final q = privateKey.q!;

  // PKCS#1 RSAPrivateKey (RFC 8017 A.1.2).
  final der = Der.sequence([
    Der.integer(BigInt.zero), // version
    Der.integer(n),
    Der.integer(e),
    Der.integer(d),
    Der.integer(p),
    Der.integer(q),
    Der.integer(d % (p - BigInt.one)), // exponent1
    Der.integer(d % (q - BigInt.one)), // exponent2
    Der.integer(q.modInverse(p)), // coefficient
  ]);

  final blob = SshWire.rsaPublicBlob(e, n);

  return GeneratedSshKey(
    privateKeyPem: Der.toPem(der, 'RSA PRIVATE KEY'),
    publicKeyLine: SshWire.authorizedKeyLine('ssh-rsa', blob, request.comment),
    fingerprint: SshWire.fingerprintOf(blob),
    algorithm: 'ssh-rsa',
    bits: request.bits,
  );
}

AsymmetricKeyPair<PublicKey, PrivateKey> _generatePair(int bits) {
  final random = FortunaRandom();
  final seed = Uint8List.fromList(
    List<int>.generate(32, (_) => math.Random.secure().nextInt(256)),
  );
  random.seed(KeyParameter(seed));

  return (RSAKeyGenerator()
        ..init(
          ParametersWithRandom(
            RSAKeyGeneratorParameters(BigInt.from(65537), bits, 64),
            random,
          ),
        ))
      .generateKeyPair();
}
