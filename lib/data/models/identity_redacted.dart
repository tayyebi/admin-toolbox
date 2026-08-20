import 'identity.dart';

extension IdentityRedaction on Identity {
  /// Clears every secret field. Used when handing an identity to code that has
  /// no business seeing the plaintext.
  Identity redacted() {
    return Identity(
      id: id,
      name: name,
      type: type,
      certificate: certificate,
      keyType: keyType,
      publicKey: publicKey,
      fingerprint: fingerprint,
      comment: comment,
      keyBits: keyBits,
      lastUsedAt: lastUsedAt,
      cryptoVersion: cryptoVersion,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
