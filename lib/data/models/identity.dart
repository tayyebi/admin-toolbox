import '../../core/utils/json_codec.dart';

import 'identity_type.dart';

export 'identity_codec.dart';
export 'identity_copy.dart';
export 'identity_redacted.dart';
export 'identity_type.dart';

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
