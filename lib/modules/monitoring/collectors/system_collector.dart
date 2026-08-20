import 'package:uuid/uuid.dart';

import '../../../data/models/metric.dart';
import 'metric_collector.dart';

class SystemCollector extends MetricCollector {
  const SystemCollector()
      : super(
          id: 'system',
          name: 'System',
          description: 'Collects general system information',
        );

  @override
  String get command => '''
uname -a 2>/dev/null
cat /etc/os-release 2>/dev/null | head -5 || cat /etc/*release 2>/dev/null | head -5
uptime -s 2>/dev/null || uptime | awk '{print \$3,\$4}' | sed 's/,\$//'
who 2>/dev/null | wc -l
date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ
hostname 2>/dev/null
''';

  @override
  List<Metric> parse(String rawOutput, String hostId) {
    final lines = rawOutput.trim().split('\n');
    final metrics = <Metric>[];
    final now = DateTime.now();
    const uuid = Uuid();

    if (lines.isNotEmpty) {
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'sys_kernel', value: lines[0].trim(), unit: '', timestamp: now));
    }

    if (lines.length >= 7) {
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'sys_os', value: lines[1].trim(), unit: '', timestamp: now));
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'sys_uptime', value: lines[2].trim(), unit: '', timestamp: now));
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'sys_logged_users', value: lines[3].trim(), unit: 'users', timestamp: now));
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'sys_time', value: lines[4].trim(), unit: '', timestamp: now));
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'sys_hostname', value: lines[5].trim(), unit: '', timestamp: now));
    }

    return metrics;
  }
}
