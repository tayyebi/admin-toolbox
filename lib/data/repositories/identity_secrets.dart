import '../../core/crypto/encryption.dart';
import '../../core/utils/logger.dart';
import '../models/identity.dart';

/// Seals and opens the three secret fields on an identity.
///
/// Split out so the repository is about rows, and this is about which fields
/// are secret and how a v1 row is read.
class IdentitySecrets {
  const IdentitySecrets();

  EncryptionService get _encryption => EncryptionService.instance;

  Identity encrypt(Identity identity) => identity.copyWith(
        password: _sealOrNull(identity.password),
        privateKey: _sealOrNull(identity.privateKey),
        passphrase: _sealOrNull(identity.passphrase),
      );

  Future<Identity> decrypt(Identity identity) async {
    // A v1 row is readable only through the legacy path; the migration pass
    // rewrites it, but a read may arrive first.
    if (identity.needsMigration) {
      return identity.copyWith(
        password: await _openLegacyOrNull(identity.password),
        privateKey: await _openLegacyOrNull(identity.privateKey),
        passphrase: await _openLegacyOrNull(identity.passphrase),
      );
    }

    return identity.copyWith(
      password: _openOrNull(identity.password),
      privateKey: _openOrNull(identity.privateKey),
      passphrase: _openOrNull(identity.passphrase),
    );
  }

  String? _sealOrNull(String? value) {
    if (value == null || value.isEmpty) return null;
    return _encryption.encryptValue(value);
  }

  /// Decryption failure propagates.
  ///
  /// The previous implementation caught the error and returned the ciphertext,
  /// which meant a corrupt record was handed to `SSHClient` as a password —
  /// a silent auth failure at best, and a base64 blob in a server's auth log
  /// at worst. A broken credential must surface as an error.
  String? _openOrNull(String? value) {
    if (value == null || value.isEmpty) return null;
    return _encryption.decryptValue(value);
  }

  Future<String?> _openLegacyOrNull(String? value) async {
    if (value == null || value.isEmpty) return null;
    final plaintext = await _encryption.legacy.decryptValue(value);
    if (plaintext == null) {
      logWarning('Legacy credential could not be decrypted; re-enter it in the vault');
      throw const VaultDecryptException('legacy record is unreadable');
    }
    return plaintext;
  }
}
