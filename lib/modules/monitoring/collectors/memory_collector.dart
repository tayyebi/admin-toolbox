import 'package:uuid/uuid.dart';

import '../../../data/models/metric.dart';
import 'metric_collector.dart';

class MemoryCollector extends MetricCollector {
  const MemoryCollector()
      : super(
          id: 'memory',
          name: 'Memory',
          description: 'Collects memory and swap usage metrics',
        );

  @override
  String get command => '''free -b | tail -2''';

  @override
  List<Metric> parse(String rawOutput, String hostId) {
    final lines = rawOutput.trim().split('\n');
    final metrics = <Metric>[];
    final now = DateTime.now();
    const uuid = Uuid();

    for (final line in lines) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 7) continue;

      final prefix = parts[0].contains('Mem') ? 'memory' : 'swap';
      final total = parts[1];
      final used = parts[2];
      final free = parts[3];
      final cached = parts.length > 5 ? parts[5] : '0';

      final totalBytes = int.tryParse(total) ?? 0;
      final usedBytes = int.tryParse(used) ?? 0;
      final usagePct = totalBytes > 0 ? ((usedBytes / totalBytes) * 100).toStringAsFixed(1) : '0.0';

      metrics.addAll([
        Metric(id: uuid.v4(), hostId: hostId, collectorId: '${prefix}_total', value: total, unit: 'bytes', timestamp: now),
        Metric(id: uuid.v4(), hostId: hostId, collectorId: '${prefix}_used', value: used, unit: 'bytes', timestamp: now),
        Metric(id: uuid.v4(), hostId: hostId, collectorId: '${prefix}_free', value: free, unit: 'bytes', timestamp: now),
        Metric(id: uuid.v4(), hostId: hostId, collectorId: '${prefix}_usage_pct', value: usagePct, unit: '%', timestamp: now),
      ]);

      if (prefix == 'memory') {
        metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'memory_cached', value: cached, unit: 'bytes', timestamp: now));
      }
    }

    return metrics;
  }
}
