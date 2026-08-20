import 'identity.dart';

extension IdentityCopy on Identity {
  Identity copyWith({
    String? id,
    String? name,
    IdentityType? type,
    String? password,
    String? privateKey,
    String? passphrase,
    String? certificate,
    String? keyType,
    String? publicKey,
    String? fingerprint,
    String? comment,
    int? keyBits,
    DateTime? lastUsedAt,
    int? cryptoVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Identity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      passphrase: passphrase ?? this.passphrase,
      certificate: certificate ?? this.certificate,
      keyType: keyType ?? this.keyType,
      publicKey: publicKey ?? this.publicKey,
      fingerprint: fingerprint ?? this.fingerprint,
      comment: comment ?? this.comment,
      keyBits: keyBits ?? this.keyBits,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      cryptoVersion: cryptoVersion ?? this.cryptoVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
