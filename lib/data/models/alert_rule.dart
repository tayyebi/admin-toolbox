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
