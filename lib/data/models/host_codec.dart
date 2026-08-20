import '../../core/utils/json_codec.dart';
import 'host.dart';

extension HostCodec on Host {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hostname': hostname,
      'port': port,
      'username': username,
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
      'connect_timeout_seconds': connectTimeoutSeconds,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
