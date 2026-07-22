class Identity {
  final String id;
  final String name;
  final String type;
  final String username;
  final String? password;
  final String? privateKey;
  final String? passphrase;
  final String? certificate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Identity({
    required this.id,
    required this.name,
    required this.type,
    required this.username,
    this.password,
    this.privateKey,
    this.passphrase,
    this.certificate,
    required this.createdAt,
    required this.updatedAt,
  });

  Identity copyWith({
    String? id,
    String? name,
    String? type,
    String? username,
    String? password,
    String? privateKey,
    String? passphrase,
    String? certificate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Identity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      passphrase: passphrase ?? this.passphrase,
      certificate: certificate ?? this.certificate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'username': username,
      'password': password,
      'private_key': privateKey,
      'passphrase': passphrase,
      'certificate': certificate,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Identity.fromMap(Map<String, dynamic> map) {
    return Identity(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String? ?? 'password',
      username: map['username'] as String,
      password: map['password'] as String?,
      privateKey: map['private_key'] as String?,
      passphrase: map['passphrase'] as String?,
      certificate: map['certificate'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  factory Identity.fromJson(Map<String, dynamic> json) {
    return Identity(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'password',
      username: json['username'] as String,
      password: json['password'] as String?,
      privateKey: json['private_key'] as String?,
      passphrase: json['passphrase'] as String?,
      certificate: json['certificate'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => toMap();
}
