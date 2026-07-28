import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../providers/providers.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/metric_card.dart';

class HostDetailScreen extends ConsumerWidget {
  final String hostId;

  const HostDetailScreen({super.key, required this.hostId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostAsync = ref.watch(hostDetailProvider(hostId));
    final healthAsync = ref.watch(healthScoreProvider(hostId));
    final metricsAsync = ref.watch(hostMetricsProvider(hostId));

    return Scaffold(
      appBar: AppBar(
        title: hostAsync.when(
          data: (host) => Text(host?.name ?? 'Host'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/hosts/$hostId/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              switch (action) {
                case 'terminal':
                  context.push('/hosts/$hostId/terminal');
                  break;
                case 'files':
                  context.push('/hosts/$hostId/files');
                  break;
                case 'monitor':
                  context.push('/hosts/$hostId/monitoring');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'terminal', child: ListTile(leading: Icon(Icons.terminal), title: Text('Terminal'), dense: true)),
              const PopupMenuItem(value: 'files', child: ListTile(leading: Icon(Icons.folder_open), title: Text('Files'), dense: true)),
              const PopupMenuItem(value: 'monitor', child: ListTile(leading: Icon(Icons.monitor_heart), title: Text('Monitoring'), dense: true)),
            ],
          ),
        ],
      ),
      body: hostAsync.when(
        data: (host) {
          if (host == null) {
            return const Center(child: Text('Host not found'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(hostDetailProvider(hostId));
              ref.invalidate(healthScoreProvider(hostId));
              ref.invalidate(hostMetricsProvider(hostId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(host, healthAsync),
                const SizedBox(height: 16),
                _buildResourceMetrics(metricsAsync),
                const SizedBox(height: 16),
                _buildSystemInfo(host),
                const SizedBox(height: 16),
                _buildActions(context, ref, host),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHeader(dynamic host, AsyncValue<int> healthAsync) {
    final statusColor = AppTheme.statusColor(host.status ?? 'unknown');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.computer, color: statusColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(host.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${host.hostname}:${host.port}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                healthAsync.when(
                  data: (score) {
                    final color = score >= 80 ? AppTheme.successGreen : score >= 50 ? AppTheme.warningOrange : AppTheme.dangerRed;
                    return Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 3),
                          ),
                          child: Center(child: Text('$score', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16))),
                        ),
                        const SizedBox(height: 4),
                        Text('Health', style: TextStyle(fontSize: 10, color: color)),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                StatusBadge(status: host.status),
                const SizedBox(width: 8),
                _InfoChip(label: host.connectionType?.toUpperCase() ?? 'SSH'),
                if (host.groupId != null) ...[
                  const SizedBox(width: 8),
                  _InfoChip(label: 'Group'),
                ],
              ],
            ),
            if ((host.tags as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: (host.tags as List).map<Widget>((tag) => Chip(
                      label: Text('$tag', style: const TextStyle(fontSize: 11)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    )).toList(),
              ),
            ],
            if (host.notes != null && (host.notes as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(host.notes, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResourceMetrics(AsyncValue<List<dynamic>> metricsAsync) {
    return metricsAsync.when(
      data: (metrics) {
        String findValue(String collectorId) {
          final match = metrics.where((m) => m.collectorId == collectorId);
          if (match.isEmpty) return '--';
          final value = match.first.value;
          final unit = match.first.unit ?? '';
          if (match.first.collectorId == 'memory_total' || match.first.collectorId == 'disk_total') {
            final bytes = int.tryParse(value);
            if (bytes != null) return formatBytes(bytes);
          }
          return '$value$unit';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resource Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: MetricCard(label: 'CPU', value: findValue('cpu_usage'), icon: Icons.memory, color: AppTheme.primaryBlue)),
                const SizedBox(width: 8),
                Expanded(child: MetricCard(label: 'Memory', value: findValue('memory_usage_pct'), icon: Icons.storage, color: AppTheme.infoCyan)),
                const SizedBox(width: 8),
                Expanded(child: MetricCard(label: 'Disk', value: findValue('disk_usage_pct'), icon: Icons.disc_full, color: AppTheme.warningOrange)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: MetricCard(label: 'Load', value: findValue('cpu_load_1m'), icon: Icons.trending_up, color: AppTheme.primaryBlue)),
                const SizedBox(width: 8),
                Expanded(child: MetricCard(label: 'Network', value: findValue('net_private_ip'), icon: Icons.wifi, color: AppTheme.successGreen)),
                const SizedBox(width: 8),
                Expanded(child: MetricCard(label: 'Processes', value: findValue('proc_running'), icon: Icons.apps, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSystemInfo(dynamic host) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Connection Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _InfoRow(label: 'Hostname', value: '${host.hostname}'),
            _InfoRow(label: 'Port', value: '${host.port}'),
            _InfoRow(label: 'Connection', value: (host.connectionType as String?)?.toUpperCase() ?? 'SSH'),
            _InfoRow(label: 'Identity', value: host.identityId ?? 'None'),
            _InfoRow(label: 'Last Seen', value: host.lastSeen != null ? (host.lastSeen as DateTime).timeAgo : 'Never'),
            _InfoRow(label: 'Status', value: host.status, valueColor: AppTheme.statusColor(host.status)),
            if ((host.metadata as Map?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Text('Metadata', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...(host.metadata as Map).entries.map<Widget>((e) =>
                  _InfoRow(label: '${e.key}', value: '${e.value}')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref, dynamic host) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/hosts/$hostId/terminal'),
                icon: const Icon(Icons.terminal, size: 18),
                label: const Text('Terminal'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: const BorderSide(color: AppTheme.borderDefault),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/hosts/$hostId/files'),
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Files'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.infoCyan,
                  side: const BorderSide(color: AppTheme.borderDefault),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/hosts/$hostId/monitoring'),
                icon: const Icon(Icons.monitor_heart, size: 18),
                label: const Text('Monitoring'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.successGreen,
                  side: const BorderSide(color: AppTheme.borderDefault),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(hostListProvider.notifier).toggleFavorite(hostId);
                },
                icon: Icon(host.favorite == true ? Icons.star : Icons.star_border, size: 18),
                label: Text(host.favorite == true ? 'Favorited' : 'Favorite'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.warningOrange,
                  side: const BorderSide(color: AppTheme.borderDefault),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/hosts/$hostId/edit'),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete Host'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.dangerRed,
                side: const BorderSide(color: AppTheme.dangerRed),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Expanded(
            flex: 3,
            child: Text(value, style: TextStyle(color: valueColor ?? AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
