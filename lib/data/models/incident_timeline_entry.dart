import '../../core/utils/json_codec.dart';

class IncidentTimelineEntry {
  final String id;
  final String action;
  final String description;
  final DateTime timestamp;
  final String? userId;

  const IncidentTimelineEntry({
    required this.id,
    required this.action,
    required this.description,
    required this.timestamp,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'user_id': userId,
    };
  }

  factory IncidentTimelineEntry.fromJson(Map<String, dynamic> json) {
    return IncidentTimelineEntry(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? 'note',
      description: json['description'] as String? ?? '',
      timestamp: parseDateOrNull(json['timestamp']) ?? DateTime.now(),
      userId: json['user_id'] as String?,
    );
  }
}
