import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import 'generated_ssh_key.dart';
import 'rsa_key_generator.dart';
import 'ssh_key_inspection.dart';
import 'ssh_wire.dart';

// Re-exported so importers can name what `inspect` and `generateRsa` return.
export 'generated_ssh_key.dart';
export 'ssh_key_inspection.dart';

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

    return _inspectParsed(trimmed, passphrase, encrypted);
  }

  SshKeyInspection _inspectParsed(String pem, String? passphrase, bool encrypted) {
    try {
      final pairs = SSHKeyPair.fromPem(pem, passphrase);
      if (pairs.isEmpty) {
        return SshKeyInspection(
          valid: false,
          encrypted: encrypted,
          error: 'No key material was found in the file.',
        );
      }
      return SshKeyInspection(valid: true, encrypted: encrypted, algorithm: pairs.first.type);
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
  List<SSHKeyPair> parse(String pem, {String? passphrase}) =>
      SSHKeyPair.fromPem(pem.trim(), passphrase);

  /// Generates an RSA key pair.
  ///
  /// Generation is CPU-bound and slow in pure Dart (seconds at 2048 bits,
  /// considerably longer at 4096), so it runs in a background isolate.
  Future<GeneratedSshKey> generateRsa({int bits = 2048, String? comment}) {
    assert(bits == 2048 || bits == 3072 || bits == 4096);
    return compute(generateRsaKey, RsaGenerationRequest(bits: bits, comment: comment));
  }

  /// Reads the fingerprint of a public key line the user pasted alongside a
  /// private key. Returns null when the line is malformed.
  String? fingerprintOfPublicKeyLine(String line) => SshWire.fingerprintOfPublicKeyLine(line);

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
