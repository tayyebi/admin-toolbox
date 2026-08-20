import '../../core/utils/json_codec.dart';
import 'incident_timeline_entry.dart';

export 'incident_timeline_entry.dart';

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
      'affected_hosts': encodeStringList(affectedHosts),
      'timeline': encodeObjectList(timeline.map((e) => e.toJson()).toList()),
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
      affectedHosts: decodeStringList(map['affected_hosts'] as String?),
      timeline: decodeObjectList(map['timeline'] as String?)
          .map(IncidentTimelineEntry.fromJson)
          .toList(),
      resolution: map['resolution'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      resolvedAt: parseDateOrNull(map['resolved_at']),
    );
  }

  bool get isOpen => status == 'open';

  Incident copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    String? severity,
    List<String>? affectedHosts,
    List<IncidentTimelineEntry>? timeline,
    String? resolution,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
  }) {
    return Incident(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      affectedHosts: affectedHosts ?? this.affectedHosts,
      timeline: timeline ?? this.timeline,
      resolution: resolution ?? this.resolution,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
