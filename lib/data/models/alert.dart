class Alert {
  final String id;
  final String name;
  final String? hostId;
  final String ruleId;
  final String condition;
  final String? threshold;
  final String severity;
  final String status;
  final bool acknowledged;
  final DateTime? silencedUntil;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;
  final String? message;

  const Alert({
    required this.id,
    required this.name,
    this.hostId,
    required this.ruleId,
    required this.condition,
    this.threshold,
    this.severity = 'warning',
    this.status = 'active',
    this.acknowledged = false,
    this.silencedUntil,
    required this.triggeredAt,
    this.resolvedAt,
    this.message,
  });

  Alert copyWith({
    String? id,
    String? name,
    String? hostId,
    String? ruleId,
    String? condition,
    String? threshold,
    String? severity,
    String? status,
    bool? acknowledged,
    DateTime? silencedUntil,
    DateTime? triggeredAt,
    DateTime? resolvedAt,
    String? message,
  }) {
    return Alert(
      id: id ?? this.id,
      name: name ?? this.name,
      hostId: hostId ?? this.hostId,
      ruleId: ruleId ?? this.ruleId,
      condition: condition ?? this.condition,
      threshold: threshold ?? this.threshold,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      acknowledged: acknowledged ?? this.acknowledged,
      silencedUntil: silencedUntil ?? this.silencedUntil,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'host_id': hostId,
      'rule_id': ruleId,
      'condition': condition,
      'threshold': threshold,
      'severity': severity,
      'status': status,
      'acknowledged': acknowledged ? 1 : 0,
      'silenced_until': silencedUntil?.toIso8601String(),
      'triggered_at': triggeredAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'message': message,
    };
  }

  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map['id'] as String,
      name: map['name'] as String,
      hostId: map['host_id'] as String?,
      ruleId: map['rule_id'] as String,
      condition: map['condition'] as String,
      threshold: map['threshold'] as String?,
      severity: map['severity'] as String? ?? 'warning',
      status: map['status'] as String? ?? 'active',
      acknowledged: (map['acknowledged'] as int?) == 1,
      silencedUntil: map['silenced_until'] != null ? DateTime.tryParse(map['silenced_until'] as String) : null,
      triggeredAt: DateTime.parse(map['triggered_at'] as String),
      resolvedAt: map['resolved_at'] != null ? DateTime.tryParse(map['resolved_at'] as String) : null,
      message: map['message'] as String?,
    );
  }
}

class AlertRule {
  final String id;
  final String name;
  final String collectorId;
  final String condition;
  final String threshold;
  final String severity;
  final String? action;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AlertRule({
    required this.id,
    required this.name,
    required this.collectorId,
    required this.condition,
    required this.threshold,
    this.severity = 'warning',
    this.action,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'collector_id': collectorId,
      'condition': condition,
      'threshold': threshold,
      'severity': severity,
      'action': action,
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AlertRule.fromMap(Map<String, dynamic> map) {
    return AlertRule(
      id: map['id'] as String,
      name: map['name'] as String,
      collectorId: map['collector_id'] as String,
      condition: map['condition'] as String,
      threshold: map['threshold'] as String,
      severity: map['severity'] as String? ?? 'warning',
      action: map['action'] as String?,
      enabled: (map['enabled'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
