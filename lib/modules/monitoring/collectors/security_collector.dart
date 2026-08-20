import 'package:uuid/uuid.dart';

import '../../../data/models/metric.dart';
import 'metric_collector.dart';

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
    const uuid = Uuid();

    if (lines.isNotEmpty) {
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
