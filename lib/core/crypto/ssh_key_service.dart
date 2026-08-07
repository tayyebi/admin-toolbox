import 'dart:math' as math;

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import 'ssh_wire.dart';

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

/// Import, validation, generation and export of SSH keys.
class SshKeyService {
  SshKeyService._();
  static final SshKeyService instance = SshKeyService._();

  /// Validates a private key without keeping it.
  ///
  /// Distinguishes the three cases the UI has to tell apart: a good key, a key
  /// that needs a passphrase, and a passphrase that is simply wrong.
  SshKeyInspection inspect(String pem, {String? passphrase}) {
    final trimmed = pem.trim();
    if (trimmed.isEmpty) {
      return const SshKeyInspection(valid: false, encrypted: false, error: 'No key supplied');
    }

    final bool encrypted;
    try {
      encrypted = SSHKeyPair.isEncryptedPem(trimmed);
    } catch (_) {
      return const SshKeyInspection(
        valid: false,
        encrypted: false,
        error: 'This does not look like an OpenSSH or PEM private key.',
      );
    }

    if (encrypted && (passphrase == null || passphrase.isEmpty)) {
      return const SshKeyInspection(valid: false, encrypted: true);
    }

    try {
      final pairs = SSHKeyPair.fromPem(trimmed, passphrase);
      if (pairs.isEmpty) {
        return SshKeyInspection(
          valid: false,
          encrypted: encrypted,
          error: 'No key material was found in the file.',
        );
      }
      return SshKeyInspection(
        valid: true,
        encrypted: encrypted,
        algorithm: pairs.first.type,
      );
    } catch (e) {
      return SshKeyInspection(
        valid: false,
        encrypted: encrypted,
        error: encrypted
            ? 'Incorrect passphrase for this key.'
            : 'The key could not be parsed: $e',
      );
    }
  }

  /// Parses a key for use, throwing if it cannot be read.
  List<SSHKeyPair> parse(String pem, {String? passphrase}) {
    return SSHKeyPair.fromPem(pem.trim(), passphrase);
  }

  /// Generates an RSA key pair.
  ///
  /// RSA rather than Ed25519 because `dartssh2` exposes no key generation and
  /// pure-Dart Ed25519 would mean hand-rolling the `openssh-key-v1` container;
  /// RSA's PKCS#1 PEM is a format we can write correctly and verify. Ed25519
  /// keys generated elsewhere import fine — this only affects generation.
  ///
  /// Key generation is CPU-bound and slow in pure Dart (seconds at 2048 bits,
  /// considerably longer at 4096), so it runs in a background isolate.
  Future<GeneratedSshKey> generateRsa({int bits = 2048, String? comment}) {
    assert(bits == 2048 || bits == 3072 || bits == 4096);
    return compute(_generateRsaKey, _RsaGenerationRequest(bits: bits, comment: comment));
  }

  /// Reads the fingerprint of a public key line the user pasted alongside a
  /// private key. Returns null when the line is malformed.
  String? fingerprintOfPublicKeyLine(String line) =>
      SshWire.fingerprintOfPublicKeyLine(line);

  String? algorithmOfPublicKeyLine(String line) => SshWire.algorithmOfPublicKeyLine(line);

  /// Shell to append a public key to `~/.ssh/authorized_keys`.
  ///
  /// Idempotent — `grep -qxF` means running it twice does not duplicate the
  /// entry — and it fixes the directory and file permissions, which sshd
  /// refuses to work around.
  String authorizedKeyInstallCommand(String publicKeyLine) {
    final escaped = publicKeyLine.trim().replaceAll("'", r"'\''");
    return "mkdir -p ~/.ssh && chmod 700 ~/.ssh && "
        "touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && "
        "grep -qxF '$escaped' ~/.ssh/authorized_keys || "
        "echo '$escaped' >> ~/.ssh/authorized_keys";
  }
}

@immutable
class _RsaGenerationRequest {
  const _RsaGenerationRequest({required this.bits, this.comment});
  final int bits;
  final String? comment;
}

/// Top-level so [compute] can run it off the UI isolate.
GeneratedSshKey _generateRsaKey(_RsaGenerationRequest request) {
  final random = FortunaRandom();
  final seed = Uint8List.fromList(
    List<int>.generate(32, (_) => math.Random.secure().nextInt(256)),
  );
  random.seed(KeyParameter(seed));

  final generator = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), request.bits, 64),
        random,
      ),
    );

  final pair = generator.generateKeyPair();
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
