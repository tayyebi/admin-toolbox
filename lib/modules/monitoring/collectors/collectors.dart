import 'package:uuid/uuid.dart';
import '../../data/models/metric.dart';
import '../../data/models/connection.dart';
import '../../data/transport/transport.dart';
import '../../core/utils/logger.dart';

abstract class MetricCollector {
  final String id;
  final String name;
  final String description;
  final Set<String> supportedOs;
  final Duration timeout;
  final Duration cacheDuration;
  final Duration refreshInterval;

  const MetricCollector({
    required this.id,
    required this.name,
    required this.description,
    this.supportedOs = const {'linux', 'bsd'},
    this.timeout = const Duration(seconds: 10),
    this.cacheDuration = const Duration(seconds: 30),
    this.refreshInterval = const Duration(seconds: 60),
  });

  String get command;
  List<Metric> parse(String rawOutput, String hostId);

  bool supports(String os) => supportedOs.contains(os.toLowerCase());

  Future<List<Metric>> collect(TransportSession transport, String hostId) async {
    try {
      final result = await transport.execute(command, timeout: timeout);
      if (result.isSuccess) {
        return parse(result.stdout, hostId);
      }
      logWarning('Collector $id failed with exit code ${result.exitCode}: ${result.stderr}');
      return [];
    } catch (e) {
      logError('Collector $id error', e);
      return [];
    }
  }
}

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
    final metrics = <Metric>[];
    final now = DateTime.now();
    final uuid = const Uuid();

    if (lines.length >= 1) {
      final cpuParts = lines[0].trim().split(RegExp(r'\s+'));
      if (cpuParts.length >= 8) {
        final user = int.tryParse(cpuParts[1]) ?? 0;
        final nice = int.tryParse(cpuParts[2]) ?? 0;
        final system = int.tryParse(cpuParts[3]) ?? 0;
        final idle = int.tryParse(cpuParts[4]) ?? 0;
        final iowait = int.tryParse(cpuParts[5]) ?? 0;
        final irq = int.tryParse(cpuParts[6]) ?? 0;
        final softirq = int.tryParse(cpuParts[7]) ?? 0;

        final total = user + nice + system + idle + iowait + irq + softirq;
        final used = total - idle;

        final usagePct = total > 0 ? ((used / total) * 100).toStringAsFixed(1) : '0.0';

        metrics.add(Metric(
          id: uuid.v4(),
          hostId: hostId,
          collectorId: 'cpu_usage',
          value: usagePct,
          unit: '%',
          timestamp: now,
        ));

        metrics.add(Metric(
          id: uuid.v4(),
          hostId: hostId,
          collectorId: 'cpu_user',
          value: user.toString(),
          unit: 'jiffies',
          timestamp: now,
        ));

        metrics.add(Metric(
          id: uuid.v4(),
          hostId: hostId,
          collectorId: 'cpu_system',
          value: system.toString(),
          unit: 'jiffies',
          timestamp: now,
        ));

        metrics.add(Metric(
          id: uuid.v4(),
          hostId: hostId,
          collectorId: 'cpu_iowait',
          value: iowait.toString(),
          unit: 'jiffies',
          timestamp: now,
        ));
      }
    }

    if (lines.length >= 2) {
      final loadParts = lines[1].trim().split(RegExp(r'\s+'));
      if (loadParts.length >= 3) {
        metrics.add(Metric(
          id: uuid.v4(),
          hostId: hostId,
          collectorId: 'cpu_load_1m',
          value: loadParts[0],
          unit: '',
          timestamp: now,
        ));
        metrics.add(Metric(
          id: uuid.v4(),
          hostId: hostId,
          collectorId: 'cpu_load_5m',
          value: loadParts[1],
          unit: '',
          timestamp: now,
        ));
        metrics.add(Metric(
          id: uuid.v4(),
          hostId: hostId,
          collectorId: 'cpu_load_15m',
          value: loadParts[2],
          unit: '',
          timestamp: now,
        ));
      }
    }

    if (lines.length >= 3) {
      final cores = int.tryParse(lines[2].trim()) ?? 0;
      metrics.add(Metric(
        id: uuid.v4(),
        hostId: hostId,
        collectorId: 'cpu_cores',
        value: cores.toString(),
        unit: 'cores',
        timestamp: now,
      ));
    }

    if (lines.length >= 4) {
      final tempMilli = int.tryParse(lines[3].trim()) ?? 0;
      final tempCelsius = (tempMilli / 1000).toStringAsFixed(1);
      metrics.add(Metric(
        id: uuid.v4(),
        hostId: hostId,
        collectorId: 'cpu_temp',
        value: tempCelsius,
        unit: '°C',
        timestamp: now,
      ));
    }

    return metrics;
  }
}

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
    final uuid = const Uuid();

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
    final uuid = const Uuid();

    for (final line in lines) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 6) continue;

      final mount = parts[5];
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
    final uuid = const Uuid();

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
    final uuid = const Uuid();

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
    final uuid = const Uuid();

    if (lines.length >= 1) {
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
    final uuid = const Uuid();

    if (sections.isEmpty || sections[0].contains('no_docker')) {
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'docker_available', value: '0', unit: '', timestamp: now));
      return metrics;
    }

    metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'docker_available', value: '1', unit: '', timestamp: now));

    if (sections.length >= 1) {
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
    final uuid = const Uuid();

    if (lines.length >= 1) {
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

class SecurityCollector extends MetricCollector {
  const SecurityCollector()
      : super(
          id: 'security',
          name: 'Security',
          description: 'Collects security-related metrics',
        );

  @override
  String get command => '''
grep -c "Failed password" /var/log/auth.log /var/log/secure 2>/dev/null | tail -1 | awk -F: '{print \$2}' || echo "0"
grep -c "Accepted" /var/log/auth.log /var/log/secure 2>/dev/null | tail -1 | awk -F: '{print \$2}' || echo "0"
if command -v ufw >/dev/null 2>&1; then ufw status | head -1; elif command -v firewall-cmd >/dev/null 2>&1; then firewall-cmd --state 2>/dev/null; elif command -v iptables >/dev/null 2>&1; then echo "iptables"; else echo "unknown"; fi
ss -tlnp 2>/dev/null | tail -n +2 | wc -l || netstat -tlnp 2>/dev/null | tail -n +3 | wc -l || echo "0"
''';

  @override
  List<Metric> parse(String rawOutput, String hostId) {
    final lines = rawOutput.trim().split('\n');
    final metrics = <Metric>[];
    final now = DateTime.now();
    final uuid = const Uuid();

    if (lines.length >= 1) {
      final failedLogins = lines[0].trim();
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'sec_failed_logins', value: failedLogins, unit: 'attempts', timestamp: now));
    }

    if (lines.length >= 2) {
      final successLogins = lines[1].trim();
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'sec_successful_logins', value: successLogins, unit: 'logins', timestamp: now));
    }

    if (lines.length >= 3) {
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'sec_firewall', value: lines[2].trim(), unit: '', timestamp: now));
    }

    if (lines.length >= 4) {
      final ports = int.tryParse(lines[3].trim()) ?? 0;
      metrics.add(Metric(id: uuid.v4(), hostId: hostId, collectorId: 'sec_open_ports', value: ports.toString(), unit: 'ports', timestamp: now));
    }

    return metrics;
  }
}

class CollectorRegistry {
  static final CollectorRegistry instance = CollectorRegistry._();

  CollectorRegistry._();

  final Map<String, MetricCollector> _collectors = {};

  void register(MetricCollector collector) {
    _collectors[collector.id] = collector;
  }

  void registerAll(List<MetricCollector> collectors) {
    for (final c in collectors) {
      register(c);
    }
  }

  MetricCollector? get(String id) => _collectors[id];

  List<MetricCollector> get all => _collectors.values.toList();

  static List<MetricCollector> defaultCollectors() {
    return [
      const CpuCollector(),
      const MemoryCollector(),
      const DiskCollector(),
      const NetworkCollector(),
      const ProcessCollector(),
      const ServiceCollector(),
      const DockerCollector(),
      const SystemCollector(),
      const SecurityCollector(),
    ];
  }
}
