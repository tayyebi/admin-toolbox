import 'package:uuid/uuid.dart';

import '../../../data/models/metric.dart';
import 'metric_collector.dart';

class ServiceCollector extends MetricCollector {
  const ServiceCollector()
      : super(
          id: 'services',
          name: 'Services',
          description: 'Collects systemd service status metrics',
        );

  @override
  String get command => '''
command -v systemctl >/dev/null 2>&1 && systemctl list-units --type=service --no-legend --state=failed 2>/dev/null | wc -l || echo "0"
command -v systemctl >/dev/null 2>&1 && systemctl list-units --type=service --no-legend --state=running 2>/dev/null | wc -l || echo "0"
command -v systemctl >/dev/null 2>&1 && systemctl list-units --type=service --no-legend --state=failed 2>/dev/null | head -10 || echo ""
''';

  @override
  List<Metric> parse(String rawOutput, String hostId) {
    final lines = rawOutput.trim().split('\n');
    final metrics = <Metric>[];
    final now = DateTime.now();
    const uuid = Uuid();

    if (lines.isNotEmpty) {
      final failed = int.tryParse(lines[0].trim()) ?? 0;
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'svc_failed', value: failed.toString(), unit: 'services', timestamp: now));
    }

    if (lines.length >= 2) {
      final running = int.tryParse(lines[1].trim()) ?? 0;
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'svc_running', value: running.toString(), unit: 'services', timestamp: now));
    }

    if (lines.length >= 3) {
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'svc_failed_list', value: lines.sublist(2).join('\n'), unit: '', timestamp: now));
    }

    return metrics;
  }
}
