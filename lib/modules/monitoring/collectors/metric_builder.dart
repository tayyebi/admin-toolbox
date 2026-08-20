import 'package:uuid/uuid.dart';

import '../../../data/models/metric.dart';

/// Accumulates the metrics one collector produces from one reading.
///
/// Every metric in a reading shares a host and a timestamp, so a parser that
/// spells those out per metric buries the part that differs — the id, the
/// value and the unit — in eight lines of ceremony each.
class MetricBuilder {
  MetricBuilder(this.hostId) : _timestamp = DateTime.now();

  final String hostId;
  final DateTime _timestamp;
  final _uuid = const Uuid();
  final _metrics = <Metric>[];

  List<Metric> get metrics => List.unmodifiable(_metrics);

  void add(String collectorId, String value, {String unit = ''}) {
    _metrics.add(
      Metric(
        id: _uuid.v4(),
        hostId: hostId,
        collectorId: collectorId,
        value: value,
        unit: unit,
        timestamp: _timestamp,
      ),
    );
  }
}
