import '../../core/utils/json_codec.dart';

/// How a host authenticates.
enum IdentityType {
  password,
  sshKey;

  static IdentityType parse(String? raw) {
    switch (raw) {
      case 'ssh_key':
      case 'sshKey':
        return IdentityType.sshKey;
      default:
        return IdentityType.password;
    }
  }

  String get storageValue => this == IdentityType.sshKey ? 'ssh_key' : 'password';

  String get label => this == IdentityType.sshKey ? 'SSH Key' : 'Password';
}

/// A credential in the vault.
///
/// [password], [privateKey] and [passphrase] hold plaintext only while an
/// instance is in flight between the repository and the UI — at rest they are
/// AES-GCM sealed. [publicKey] and [fingerprint] are deliberately *not*
/// secret, so the vault list can render without decrypting every record.
class Identity {
  const Identity({
    required this.id,
    required this.name,
    required this.type,
    this.password,
    this.privateKey,
    this.passphrase,
    this.certificate,
    this.keyType,
    this.publicKey,
    this.fingerprint,
    this.comment,
    this.keyBits,
    this.lastUsedAt,
    this.cryptoVersion = 2,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final IdentityType type;
  final String? password;
  final String? privateKey;
  final String? passphrase;
  final String? certificate;

  /// OpenSSH algorithm name, e.g. `ssh-ed25519`, `ssh-rsa`.
  final String? keyType;

  /// The OpenSSH public key line, safe to display and share.
  final String? publicKey;

  /// `SHA256:…`, matching what `ssh-keygen -lf` prints.
  final String? fingerprint;

  final String? comment;
  final int? keyBits;
  final DateTime? lastUsedAt;

  /// 1 = legacy AES-CBC, 2 = AES-GCM. Drives lazy re-encryption.
  final int cryptoVersion;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isKeyBased => type == IdentityType.sshKey;
  bool get hasPassphrase => passphrase != null && passphrase!.isNotEmpty;
  bool get needsMigration => cryptoVersion < 2;

  /// Short form for list rows: `SHA256:abc…xyz`.
  String get shortFingerprint {
    final fp = fingerprint;
    if (fp == null || fp.length < 20) return fp ?? '';
    return '${fp.substring(0, 14)}…${fp.substring(fp.length - 6)}';
  }

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

  factory Identity.fromMap(Map<String, dynamic> map) {
    return Identity(
      id: map['id'] as String,
      name: map['name'] as String,
      type: IdentityType.parse(map['type'] as String?),
      password: map['password'] as String?,
      privateKey: map['private_key'] as String?,
      passphrase: map['passphrase'] as String?,
      certificate: map['certificate'] as String?,
      keyType: map['key_type'] as String?,
      publicKey: map['public_key'] as String?,
      fingerprint: map['fingerprint'] as String?,
      comment: map['comment'] as String?,
      keyBits: map['key_bits'] as int?,
      lastUsedAt: parseDateOrNull(map['last_used_at']),
      cryptoVersion: (map['crypto_version'] as int?) ?? 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Secrets are omitted so an identity can never leak through a log line or
  /// an error message.
  @override
  String toString() =>
      'Identity(id: $id, name: $name, type: ${type.storageValue}, '
      'fingerprint: ${fingerprint ?? '-'}, secrets: <redacted>)';
}
