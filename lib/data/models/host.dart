class Host {
  final String id;
  final String name;
  final String hostname;
  final int port;
  final String? groupId;
  final String? identityId;
  final String connectionType;
  final List<String> tags;
  final String? notes;
  final bool favorite;
  final Map<String, String> metadata;
  final String status;
  final DateTime? lastSeen;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Host({
    required this.id,
    required this.name,
    required this.hostname,
    this.port = 22,
    this.groupId,
    this.identityId,
    this.connectionType = 'ssh',
    this.tags = const [],
    this.notes,
    this.favorite = false,
    this.metadata = const {},
    this.status = 'unknown',
    this.lastSeen,
    required this.createdAt,
    required this.updatedAt,
  });

  Host copyWith({
    String? id,
    String? name,
    String? hostname,
    int? port,
    String? groupId,
    String? identityId,
    String? connectionType,
    List<String>? tags,
    String? notes,
    bool? favorite,
    Map<String, String>? metadata,
    String? status,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Host(
      id: id ?? this.id,
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      groupId: groupId ?? this.groupId,
      identityId: identityId ?? this.identityId,
      connectionType: connectionType ?? this.connectionType,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      favorite: favorite ?? this.favorite,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hostname': hostname,
      'port': port,
      'group_id': groupId,
      'identity_id': identityId,
      'connection_type': connectionType,
      'tags': tags.join(','),
      'notes': notes,
      'favorite': favorite ? 1 : 0,
      'metadata': _encodeMap(metadata),
      'status': status,
      'last_seen': lastSeen?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': (updatedAt).toIso8601String(),
    };
  }

  factory Host.fromMap(Map<String, dynamic> map) {
    return Host(
      id: map['id'] as String,
      name: map['name'] as String,
      hostname: map['hostname'] as String,
      port: map['port'] as int? ?? 22,
      groupId: map['group_id'] as String?,
      identityId: map['identity_id'] as String?,
      connectionType: map['connection_type'] as String? ?? 'ssh',
      tags: _parseTags(map['tags'] as String?),
      notes: map['notes'] as String?,
      favorite: (map['favorite'] as int?) == 1,
      metadata: _decodeMap(map['metadata'] as String?),
      status: map['status'] as String? ?? 'unknown',
      lastSeen: map['last_seen'] != null ? DateTime.tryParse(map['last_seen'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static List<String> _parseTags(String? tagsStr) {
    if (tagsStr == null || tagsStr.isEmpty) return [];
    return tagsStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  static String _encodeMap(Map<String, String> map) {
    return map.entries.map((e) => '${e.key}=${e.value}').join(',');
  }

  static Map<String, String> _decodeMap(String? str) {
    if (str == null || str.isEmpty) return {};
    final map = <String, String>{};
    for (final pair in str.split(',')) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        map[parts[0].trim()] = parts[1].trim();
      }
    }
    return map;
  }
}
