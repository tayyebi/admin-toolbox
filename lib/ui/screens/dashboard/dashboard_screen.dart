import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../providers/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hosts = ref.watch(hostsProvider);
    final alerts = ref.watch(alertsProvider);
    final incidents = ref.watch(incidentsProvider);
    final statusCounts = ref.watch(hostStatusCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Host',
            onPressed: () => context.push('/hosts/new'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(hostsProvider);
          ref.invalidate(alertsProvider);
          ref.invalidate(incidentsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusOverview(statusCounts),
            const SizedBox(height: 16),
            _buildFleetStats(hosts),
            const SizedBox(height: 16),
            _buildQuickActions(context),
            const SizedBox(height: 16),
            _buildAlertsSection(alerts),
            const SizedBox(height: 16),
            _buildIncidentsSection(incidents),
            const SizedBox(height: 16),
            _buildRecentHosts(hosts),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverview(AsyncValue<Map<String, int>> statusCounts) {
    return statusCounts.when(
      data: (counts) {
        final total = counts.values.fold(0, (a, b) => a + b);
        final online = counts['online'] ?? 0;
        final offline = counts['offline'] ?? 0;
        final warning = counts['warning'] ?? 0;

        return Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total Hosts',
                value: '$total',
                icon: Icons.computer,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'Online',
                value: '$online',
                icon: Icons.check_circle,
                color: AppTheme.successGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'Warning',
                value: '$warning',
                icon: Icons.warning_amber,
                color: AppTheme.warningOrange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'Offline',
                value: '$offline',
                icon: Icons.error,
                color: AppTheme.dangerRed,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
      },
      loading: () => const SizedBox(height: 80),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _buildFleetStats(AsyncValue<List<dynamic>> hosts) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fleet Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniStat(label: 'Avg CPU', value: '--'),
                _MiniStat(label: 'Avg RAM', value: '--'),
                _MiniStat(label: 'Alerts', value: '--'),
                _MiniStat(label: 'Uptime', value: '--'),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QuickActionChip(
              icon: Icons.terminal,
              label: 'Terminal',
              onTap: () => context.push('/hosts'),
            ),
            _QuickActionChip(
              icon: Icons.folder_open,
              label: 'Files',
              onTap: () => context.push('/hosts'),
            ),
            _QuickActionChip(
              icon: Icons.playlist_play,
              label: 'Automation',
              onTap: () => context.push('/automation'),
            ),
            _QuickActionChip(
              icon: Icons.bug_report,
              label: 'Incidents',
              onTap: () => context.push('/incidents'),
            ),
            _QuickActionChip(
              icon: Icons.run_circle,
              label: 'Batch Ops',
              onTap: () {},
            ),
            _QuickActionChip(
              icon: Icons.keyboard_command_key,
              label: 'Commands',
              onTap: () {},
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 300.ms);
  }

  Widget _buildAlertsSection(AsyncValue<List<dynamic>> alerts) {
    return alerts.when(
      data: (alertList) {
        if (alertList.isEmpty) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Alerts (${alertList.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.warningOrange),
                    ),
                    TextButton(onPressed: () => {}, child: const Text('View All')),
                  ],
                ),
                const SizedBox(height: 8),
                ...alertList.take(3).map((alert) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.warning_amber,
                        color: AppTheme.severityColor(alert.severity ?? 'warning'),
                      ),
                      title: Text(alert.name ?? 'Unknown', style: const TextStyle(fontSize: 14)),
                      subtitle: Text(alert.message ?? '', style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                    )),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildIncidentsSection(AsyncValue<List<dynamic>> incidents) {
    return incidents.when(
      data: (list) {
        final open = list.where((i) => i.status == 'open').toList();
        if (open.isEmpty) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Open Incidents (${open.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.dangerRed)),
                    TextButton(onPressed: () => {}, child: const Text('View All')),
                  ],
                ),
                ...open.take(3).map((incident) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.bug_report, color: AppTheme.severityColor(incident.severity)),
                      title: Text(incident.title, style: const TextStyle(fontSize: 14)),
                      subtitle: Text('Created ${(incident.createdAt as DateTime?)?.timeAgo ?? ''}', style: const TextStyle(fontSize: 12)),
                    )),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecentHosts(AsyncValue<List<dynamic>> hosts) {
    return hosts.when(
      data: (hostList) {
        if (hostList.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.computer, size: 48, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  const Text('No hosts added yet', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('Add Your First Host'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hosts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...hostList.take(5).map((host) => _HostListTile(host: host)),
          ],
        );
      },
      loading: () => const Card(
        child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e'))),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppTheme.bgSurface,
    );
  }
}

class _HostListTile extends StatelessWidget {
  final dynamic host;

  const _HostListTile({required this.host});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.statusColor(host.status ?? 'unknown');
    return Card(
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
            boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.4), blurRadius: 6)],
          ),
        ),
        title: Text(host.name ?? host.hostname, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('${host.hostname}:${host.port}', style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => context.push('/hosts/${host.id}'),
      ),
    );
  }
}
