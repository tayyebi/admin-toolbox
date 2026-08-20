import 'package:uuid/uuid.dart';

import '../../../data/models/metric.dart';
import 'metric_collector.dart';

class ProcessCollector extends MetricCollector {
  const ProcessCollector()
      : super(
          id: 'processes',
          name: 'Processes',
          description: 'Collects process count and top CPU/memory processes',
        );

  @override
  String get command => '''
ps aux --no-headers 2>/dev/null | wc -l
ps aux --no-headers --sort=-%cpu 2>/dev/null | head -5 | awk '{print \$11 ":" \$3}'
ps aux --no-headers --sort=-%mem 2>/dev/null | head -5 | awk '{print \$11 ":" \$4}'
grep -c zombie /proc/*/status 2>/dev/null || echo "0"
''';

  @override
  List<Metric> parse(String rawOutput, String hostId) {
    final sections = rawOutput.trim().split('\n\n');
    final metrics = <Metric>[];
    final now = DateTime.now();
    const uuid = Uuid();

    if (sections.isNotEmpty) {
      final count = int.tryParse(sections[0].trim()) ?? 0;
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'proc_running', value: count.toString(), unit: 'processes', timestamp: now));
    }

    if (sections.length >= 2) {
      final topCpuLines = sections[1].trim().split('\n');
      for (var i = 0; i < topCpuLines.length; i++) {
        final parts = topCpuLines[i].split(':');
        if (parts.length >= 2) {
          metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'proc_top_cpu_$i', value: '${parts[0]}=${parts[1]}%', unit: '', timestamp: now));
        }
      }
    }

    if (sections.length >= 3) {
      final topMemLines = sections[2].trim().split('\n');
      for (var i = 0; i < topMemLines.length; i++) {
        final parts = topMemLines[i].split(':');
        if (parts.length >= 2) {
          metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'proc_top_mem_$i', value: '${parts[0]}=${parts[1]}%', unit: '', timestamp: now));
        }
      }
    }

    if (sections.length >= 4) {
      final zombies = int.tryParse(sections[3].trim()) ?? 0;
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'proc_zombies', value: zombies.toString(), unit: 'processes', timestamp: now));
    }

    return metrics;
  }
}
