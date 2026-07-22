class Incident {
  final String id;
  final String title;
  final String? description;
  final String status;
  final String severity;
  final List<String> affectedHosts;
  final List<IncidentTimelineEntry> timeline;
  final String? resolution;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  const Incident({
    required this.id,
    required this.title,
    this.description,
    this.status = 'open',
    this.severity = 'medium',
    this.affectedHosts = const [],
    this.timeline = const [],
    this.resolution,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'severity': severity,
      'affected_hosts': affectedHosts.join(','),
      'timeline': timeline.map((e) => e.toJson()).join('\n\n'),
      'resolution': resolution,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  factory Incident.fromMap(Map<String, dynamic> map) {
    return Incident(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      status: map['status'] as String? ?? 'open',
      severity: map['severity'] as String? ?? 'medium',
      affectedHosts: (map['affected_hosts'] as String?)?.split(',').where((h) => h.isNotEmpty).toList() ?? [],
      timeline: [],
      resolution: map['resolution'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      resolvedAt: map['resolved_at'] != null ? DateTime.tryParse(map['resolved_at'] as String) : null,
    );
  }
}

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
}
