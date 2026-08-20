import 'alert.dart';

extension AlertCopy on Alert {
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
}
