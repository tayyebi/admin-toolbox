class Metric {
  final String id;
  final String hostId;
  final String collectorId;
  final String value;
  final String? unit;
  final DateTime timestamp;

  const Metric({
    required this.id,
    required this.hostId,
    required this.collectorId,
    required this.value,
    this.unit,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'host_id': hostId,
      'collector_id': collectorId,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Metric.fromMap(Map<String, dynamic> map) {
    return Metric(
      id: map['id'] as String,
      hostId: map['host_id'] as String,
      collectorId: map['collector_id'] as String,
      value: map['value'] as String,
      unit: map['unit'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  double? get numericValue => double.tryParse(value);
}

class MetricSeries {
  final String hostId;
  final String collectorId;
  final List<Metric> metrics;

  const MetricSeries({
    required this.hostId,
    required this.collectorId,
    required this.metrics,
  });

  double get average {
    if (metrics.isEmpty) return 0;
    final values = metrics.map((m) => m.numericValue).whereType<double>();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double get max {
    final values = metrics.map((m) => m.numericValue).whereType<double>();
    return values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
  }

  double get min {
    final values = metrics.map((m) => m.numericValue).whereType<double>();
    return values.isEmpty ? 0 : values.reduce((a, b) => a < b ? a : b);
  }
}
