import '../../core/utils/json_codec.dart';

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

  /// When true, the background monitoring loop skips this host — it never
  /// opens a connection on its own. Manual actions (terminal, files, test
  /// connection) are unaffected.
  final bool monitoringPaused;

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
    this.monitoringPaused = false,
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
    bool? monitoringPaused,
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
      monitoringPaused: monitoringPaused ?? this.monitoringPaused,
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
      'tags': encodeStringList(tags),
      'notes': notes,
      'favorite': favorite ? 1 : 0,
      'metadata': encodeStringMap(metadata),
      'status': status,
      'last_seen': lastSeen?.toIso8601String(),
      'monitoring_paused': monitoringPaused ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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
      tags: decodeStringList(map['tags'] as String?),
      notes: map['notes'] as String?,
      favorite: (map['favorite'] as int?) == 1,
      metadata: decodeStringMap(map['metadata'] as String?),
      status: map['status'] as String? ?? 'unknown',
      lastSeen: parseDateOrNull(map['last_seen']),
      monitoringPaused: (map['monitoring_paused'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// `user@hostname:port`, or `hostname:port` when no identity is attached.
  String get endpoint => '$hostname:$port';

  @override
  String toString() => 'Host(id: $id, name: $name, endpoint: $endpoint, status: $status)';
}
