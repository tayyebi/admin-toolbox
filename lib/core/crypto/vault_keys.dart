/// Secure-storage key names for the vault.
///
/// The vault has no version byte inside its sealed blobs; generation is
/// inferred from *which* of these keys exist, and each wrap stores its own KDF
/// parameters alongside it. Adding a new wrap therefore means adding new keys
/// here, never changing the blob format.
abstract final class VaultKeys {
  /// Current generation.
  static const salt = 'vault.kdf_salt';
  static const wrappedDek = 'vault.wrapped_dek';
  static const biometricDek = 'vault.biometric_dek';
  static const kdfIterations = 'vault.kdf_iterations';

  /// Pre-migration, read only so v1 vaults can be upgraded in place.
  static const legacyKey = 'master_encryption_key';
  static const legacySalt = 'master_encryption_salt';
}
