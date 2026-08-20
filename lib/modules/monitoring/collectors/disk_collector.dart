import 'package:uuid/uuid.dart';

import '../../../data/models/metric.dart';
import 'metric_collector.dart';

class DiskCollector extends MetricCollector {
  const DiskCollector()
      : super(
          id: 'disk',
          name: 'Disk',
          description: 'Collects disk usage and inode metrics',
        );

  @override
  String get command => '''df -B1 2>/dev/null | tail -n +2''';

  @override
  List<Metric> parse(String rawOutput, String hostId) {
    final lines = rawOutput.trim().split('\n');
    final metrics = <Metric>[];
    final now = DateTime.now();
    const uuid = Uuid();

    for (final line in lines) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 6) continue;

      final total = int.tryParse(parts[1]) ?? 0;
      final used = int.tryParse(parts[2]) ?? 0;
      final free = int.tryParse(parts[3]) ?? 0;
      final usagePct = parts[4].replaceAll('%', '');
      final inodes = parts.length > 6 ? parts[6] : '';

      metrics.addAll([
        Metric(id: uuid.v4(), hostId: hostId, collectorId: 'disk_total', value: total.toString(), unit: 'bytes', timestamp: now),
        Metric(id: uuid.v4(), hostId: hostId, collectorId: 'disk_used', value: used.toString(), unit: 'bytes', timestamp: now),
        Metric(id: uuid.v4(), hostId: hostId, collectorId: 'disk_free', value: free.toString(), unit: 'bytes', timestamp: now),
        Metric(id: uuid.v4(), hostId: hostId, collectorId: 'disk_usage_pct', value: usagePct, unit: '%', timestamp: now),
        Metric(id: uuid.v4(), hostId: hostId, collectorId: 'disk_inodes', value: inodes, unit: 'inodes', timestamp: now),
      ]);
    }

    return metrics;
  }
}
