/// Thrown when the vault is asked to encrypt or decrypt while locked.
class VaultLockedException implements Exception {
  const VaultLockedException();

  @override
  String toString() => 'Vault is locked';
}

/// Thrown when a stored secret fails to decrypt — wrong key, or the ciphertext
/// was truncated or tampered with. Never swallow this: returning ciphertext in
/// place of a plaintext credential would hand a base64 blob to an SSH server.
class VaultDecryptException implements Exception {
  const VaultDecryptException(this.message);

  final String message;

  @override
  String toString() => 'Failed to decrypt vault record: $message';
}
