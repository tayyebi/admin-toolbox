import 'identity.dart';

extension IdentityCodec on Identity {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.storageValue,
      'password': password,
      'private_key': privateKey,
      'passphrase': passphrase,
      'certificate': certificate,
      'key_type': keyType,
      'public_key': publicKey,
      'fingerprint': fingerprint,
      'comment': comment,
      'key_bits': keyBits,
      'last_used_at': lastUsedAt?.toIso8601String(),
      'crypto_version': cryptoVersion,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
