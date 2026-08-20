import 'host.dart';

extension HostCopy on Host {
  Host copyWith({
    String? id,
    String? name,
    String? hostname,
    int? port,
    String? username,
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
    int? connectTimeoutSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Host(
      id: id ?? this.id,
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      username: username ?? this.username,
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
      connectTimeoutSeconds: connectTimeoutSeconds ?? this.connectTimeoutSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
