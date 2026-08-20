import 'package:uuid/uuid.dart';

import '../../../data/models/metric.dart';
import 'metric_collector.dart';

class DockerCollector extends MetricCollector {
  const DockerCollector()
      : super(
          id: 'docker',
          name: 'Docker',
          description: 'Collects Docker container metrics',
        );

  @override
  String get command => '''
command -v docker >/dev/null 2>&1 && docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}\t{{.Image}}" --no-trunc 2>/dev/null || echo "no_docker"
command -v docker >/dev/null 2>&1 && docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || echo "no_docker"
''';

  @override
  List<Metric> parse(String rawOutput, String hostId) {
    final sections = rawOutput.trim().split('\n\n');
    final metrics = <Metric>[];
    final now = DateTime.now();
    const uuid = Uuid();

    if (sections.isEmpty || sections[0].contains('no_docker')) {
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'docker_available', value: '0', unit: '', timestamp: now));
      return metrics;
    }

    metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'docker_available', value: '1', unit: '', timestamp: now));

    if (sections.isNotEmpty) {
      final containerLines = sections[0].split('\n').skip(1);
      var count = 0;
      for (final line in containerLines) {
        if (line.isEmpty) continue;
        count++;
        metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'docker_container_$count', value: line.trim(), unit: '', timestamp: now));
      }
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'docker_containers', value: count.toString(), unit: 'containers', timestamp: now));
    }

    return metrics;
  }
}
