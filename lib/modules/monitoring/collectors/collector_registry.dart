import 'cpu_collector.dart';
import 'disk_collector.dart';
import 'docker_collector.dart';
import 'memory_collector.dart';
import 'metric_collector.dart';
import 'network_collector.dart';
import 'process_collector.dart';
import 'security_collector.dart';
import 'service_collector.dart';
import 'system_collector.dart';

class CollectorRegistry {
  CollectorRegistry._();
  static final CollectorRegistry instance = CollectorRegistry._();

  final Map<String, MetricCollector> _collectors = {};

  void register(MetricCollector collector) => _collectors[collector.id] = collector;

  void registerAll(List<MetricCollector> collectors) {
    for (final collector in collectors) {
      register(collector);
    }
  }

  MetricCollector? get(String id) => _collectors[id];

  List<MetricCollector> get all => _collectors.values.toList();

  static List<MetricCollector> defaultCollectors() => const [
        CpuCollector(),
        MemoryCollector(),
        DiskCollector(),
        NetworkCollector(),
        ProcessCollector(),
        ServiceCollector(),
        DockerCollector(),
        SystemCollector(),
        SecurityCollector(),
      ];
}
