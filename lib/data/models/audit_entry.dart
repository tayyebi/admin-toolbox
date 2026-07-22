class AuditEntry {
  final String id;
  final String action;
  final String entityType;
  final String? entityId;
  final String? hostId;
  final String? details;
  final String? userId;
  final DateTime timestamp;

  const AuditEntry({
    required this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    this.hostId,
    this.details,
    this.userId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'host_id': hostId,
      'details': details,
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AuditEntry.fromMap(Map<String, dynamic> map) {
    return AuditEntry(
      id: map['id'] as String,
      action: map['action'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String?,
      hostId: map['host_id'] as String?,
      details: map['details'] as String?,
      userId: map['user_id'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
