import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../providers/providers.dart';
import '../../widgets/metric_card.dart';

class MonitoringScreen extends ConsumerWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostsAsync = ref.watch(hostsProvider);
    final alertsAsync = ref.watch(alertsProvider);
    final statusCountsAsync = ref.watch(hostStatusCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(hostsProvider);
          ref.invalidate(alertsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFleetOverview(statusCountsAsync),
            const SizedBox(height: 16),
            _buildAlertsList(alertsAsync),
            const SizedBox(height: 16),
            _buildHostStatus(hostsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildFleetOverview(AsyncValue<Map<String, int>> statusCounts) {
    return statusCounts.when(
      data: (counts) {
        final total = counts.values.fold(0, (a, b) => a + b);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fleet Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatusIndicator(label: 'Total', count: total, color: AppTheme.primaryBlue),
                    _StatusIndicator(label: 'Online', count: counts['online'] ?? 0, color: AppTheme.successGreen),
                    _StatusIndicator(label: 'Offline', count: counts['offline'] ?? 0, color: AppTheme.dangerRed),
                    _StatusIndicator(label: 'Warning', count: counts['warning'] ?? 0, color: AppTheme.warningOrange),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAlertsList(AsyncValue<List<dynamic>> alertsAsync) {
    return alertsAsync.when(
      data: (alerts) {
        if (alerts.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Active Alerts (${alerts.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                TextButton(onPressed: () {}, child: const Text('View All')),
              ],
            ),
            const SizedBox(height: 8),
            ...alerts.map((alert) => Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.warning_amber,
                      color: AppTheme.severityColor(alert.severity ?? 'warning'),
                    ),
                    title: Text(alert.name ?? 'Alert', style: const TextStyle(fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (alert.message != null) Text(alert.message!, style: const TextStyle(fontSize: 12)),
                        Text((alert.triggeredAt as DateTime).timeAgo, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, size: 18, color: AppTheme.successGreen),
                          onPressed: () {},
                          tooltip: 'Acknowledge',
                        ),
                        IconButton(
                          icon: const Icon(Icons.visibility_off, size: 18, color: AppTheme.textMuted),
                          onPressed: () {},
                          tooltip: 'Silence',
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildHostStatus(AsyncValue<List<dynamic>> hostsAsync) {
    return hostsAsync.when(
      data: (hosts) {
        if (hosts.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Host Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...hosts.map((host) => Card(
                  child: ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.statusColor(host.status ?? 'unknown'),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.statusColor(host.status ?? 'unknown').withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    title: Text(host.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                    subtitle: Text(host.hostname, style: const TextStyle(fontSize: 12)),
                    trailing: Text(
                      host.lastSeen != null ? (host.lastSeen as DateTime).timeAgo : 'Never',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                )),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusIndicator({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
