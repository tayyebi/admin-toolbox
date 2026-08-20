import 'package:uuid/uuid.dart';

import '../../../data/models/metric.dart';
import 'metric_collector.dart';

class NetworkCollector extends MetricCollector {
  const NetworkCollector()
      : super(
          id: 'network',
          name: 'Network',
          description: 'Collects network interface and throughput metrics',
        );

  @override
  String get command => '''
cat /proc/net/dev 2>/dev/null | tail -n +3
hostname -I 2>/dev/null || echo ""
curl -s --max-time 5 ifconfig.me 2>/dev/null || echo ""
''';

  @override
  List<Metric> parse(String rawOutput, String hostId) {
    final sections = rawOutput.trim().split('\n\n');
    final metrics = <Metric>[];
    final now = DateTime.now();
    const uuid = Uuid();

    if (sections.isNotEmpty) {
      final lines = sections[0].split('\n');
      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 10) continue;

        final iface = parts[0].replaceAll(':', '');
        final rxBytes = parts[1];
        final rxErrors = parts[3];
        final rxDrops = parts[4];
        final txBytes = parts[9];
        final txErrors = parts[11];
        final txDrops = parts[12];

        metrics.addAll([
          Metric(id: uuid.v4(), hostId: hostId, collectorId: 'net_${iface}_rx_bytes', value: rxBytes, unit: 'bytes', timestamp: now),
          Metric(id: uuid.v4(), hostId: hostId, collectorId: 'net_${iface}_rx_errors', value: rxErrors, unit: 'errors', timestamp: now),
          Metric(id: uuid.v4(), hostId: hostId, collectorId: 'net_${iface}_rx_dropped', value: rxDrops, unit: 'dropped', timestamp: now),
          Metric(id: uuid.v4(), hostId: hostId, collectorId: 'net_${iface}_tx_bytes', value: txBytes, unit: 'bytes', timestamp: now),
          Metric(id: uuid.v4(), hostId: hostId, collectorId: 'net_${iface}_tx_errors', value: txErrors, unit: 'errors', timestamp: now),
          Metric(id: uuid.v4(), hostId: hostId, collectorId: 'net_${iface}_tx_dropped', value: txDrops, unit: 'dropped', timestamp: now),
        ]);
      }
    }

    if (sections.length >= 2) {
      metrics.add(Metric(
        id: uuid.v4(), hostId: hostId, collectorId: 'net_private_ip', value: sections[1].trim(), unit: '', timestamp: now,
      ));
    }

    if (sections.length >= 3) {
      metrics.add(Metric(
        id: uuid.v4(), hostId: hostId, collectorId: 'net_public_ip', value: sections[2].trim(), unit: '', timestamp: now,
      ));
    }

    return metrics;
  }
}
