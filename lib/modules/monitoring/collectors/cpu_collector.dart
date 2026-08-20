import '../../../data/models/metric.dart';
import 'metric_builder.dart';
import 'metric_collector.dart';

class CpuCollector extends MetricCollector {
  const CpuCollector()
      : super(
          id: 'cpu',
          name: 'CPU',
          description: 'Collects CPU usage, load, and temperature metrics',
        );

  @override
  String get command => '''
cat /proc/stat 2>/dev/null | head -1
cat /proc/loadavg 2>/dev/null
nproc 2>/dev/null
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null; else echo "0"; fi
uptime 2>/dev/null | awk '{print \$NF}' || echo ""
''';

  @override
  List<Metric> parse(String rawOutput, String hostId) {
    final lines = rawOutput.trim().split('\n');
    final out = MetricBuilder(hostId);

    if (lines.isNotEmpty) _parseCpuTimes(lines[0], out);
    if (lines.length >= 2) _parseLoadAverage(lines[1], out);

    if (lines.length >= 3) {
      final cores = int.tryParse(lines[2].trim()) ?? 0;
      out.add('cpu_cores', cores.toString(), unit: 'cores');
    }

    if (lines.length >= 4) {
      final tempMilli = int.tryParse(lines[3].trim()) ?? 0;
      out.add('cpu_temp', (tempMilli / 1000).toStringAsFixed(1), unit: '°C');
    }

    return out.metrics;
  }

  /// The `cpu` line of /proc/stat: cumulative jiffies per state since boot.
  static void _parseCpuTimes(String line, MetricBuilder out) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 8) return;

    int at(int index) => int.tryParse(parts[index]) ?? 0;

    final user = at(1);
    final nice = at(2);
    final system = at(3);
    final idle = at(4);
    final iowait = at(5);
    final irq = at(6);
    final softirq = at(7);

    final total = user + nice + system + idle + iowait + irq + softirq;
    final used = total - idle;

    out.add(
      'cpu_usage',
      total > 0 ? ((used / total) * 100).toStringAsFixed(1) : '0.0',
      unit: '%',
    );
    out.add('cpu_user', user.toString(), unit: 'jiffies');
    out.add('cpu_system', system.toString(), unit: 'jiffies');
    out.add('cpu_iowait', iowait.toString(), unit: 'jiffies');
  }

  static void _parseLoadAverage(String line, MetricBuilder out) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 3) return;

    out.add('cpu_load_1m', parts[0]);
    out.add('cpu_load_5m', parts[1]);
    out.add('cpu_load_15m', parts[2]);
  }
}
