class LogEntry {
  final String id;
  final String level;
  final String message;
  final DateTime timestamp;

  const LogEntry({
    required this.id,
    required this.level,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'level': level,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'] as String,
      level: map['level'] as String,
      message: map['message'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
