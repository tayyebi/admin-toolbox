import '../../core/utils/json_codec.dart';

export 'host_codec.dart';
export 'host_copy.dart';

class Host {
  final String id;
  final String name;
  final String hostname;
  final int port;

  /// The account to authenticate as on this host. A vault identity (SSH key
  /// or password) can be reused across many hosts under different usernames,
  /// so this lives on the host, not the credential.
  final String username;
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

  /// How long to wait for the initial SSH handshake before giving up.
  /// Configurable per host since latency and network paths vary widely.
  final int connectTimeoutSeconds;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Host({
    required this.id,
    required this.name,
    required this.hostname,
    this.port = 22,
    this.username = 'root',
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
    this.connectTimeoutSeconds = 30,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Host.fromMap(Map<String, dynamic> map) {
    return Host(
      id: map['id'] as String,
      name: map['name'] as String,
      hostname: map['hostname'] as String,
      port: map['port'] as int? ?? 22,
      username: map['username'] as String? ?? 'root',
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
      connectTimeoutSeconds: map['connect_timeout_seconds'] as int? ?? 30,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// `user@hostname:port`.
  String get endpoint => '$username@$hostname:$port';

  @override
  String toString() => 'Host(id: $id, name: $name, endpoint: $endpoint, status: $status)';
}
