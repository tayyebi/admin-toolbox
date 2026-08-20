export 'alert_copy.dart';
export 'alert_rule.dart';

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
