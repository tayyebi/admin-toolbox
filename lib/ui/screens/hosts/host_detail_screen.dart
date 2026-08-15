import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/host.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/status_badge.dart';

class HostDetailScreen extends ConsumerWidget {
  const HostDetailScreen({super.key, required this.hostId});

  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostAsync = ref.watch(hostDetailProvider(hostId));

    return Scaffold(
      appBar: AppBar(
        title: Text(hostAsync.valueOrNull?.name ?? 'Host'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/hosts/$hostId/edit'),
          ),
        ],
      ),
      body: hostAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(hostDetailProvider(hostId)),
        ),
        data: (host) {
          if (host == null) {
            return const EmptyState(icon: Icons.search_off, title: 'Host not found');
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(hostDetailProvider(hostId));
              ref.invalidate(healthScoreProvider(hostId));
              ref.invalidate(hostMetricsProvider(hostId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                _Header(host: host, hostId: hostId),
                const SizedBox(height: 8),
                _ResourceMetrics(hostId: hostId),
                const SizedBox(height: 8),
                _ConnectionInfo(host: host),
                const SizedBox(height: 8),
                _Actions(host: host),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.host, required this.hostId});

  final Host host;
  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final statusColor = colors.status(host.status);
    final health = ref.watch(healthScoreProvider(hostId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.dns_outlined, color: statusColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(host.name, style: context.text.headlineSmall),
                      const SizedBox(height: 2),
                      Text(
                        host.endpoint,
                        style: AppTypography.monoSmall(colors.textMuted),
                      ),
                    ],
                  ),
                ),
                health.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (score) {
                    final color = colors.health(score);
                    return Column(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2.5),
                          ),
                          child: Center(
                            child: Text('$score', style: AppTypography.monoStyle(
                              size: 15,
                              weight: FontWeight.w600,
                              color: color,
                            )),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Health',
                          style: context.text.labelSmall?.copyWith(color: color),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                StatusBadge(status: host.status),
                const SizedBox(width: 8),
                _Chip(label: host.connectionType.toUpperCase()),
              ],
            ),
            if (host.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in host.tags)
                    Chip(
                      label: Text(tag),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (host.notes != null && host.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(host.notes!, style: context.text.bodySmall),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResourceMetrics extends ConsumerWidget {
  const _ResourceMetrics({required this.hostId});

  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(hostMetricsProvider(hostId));

    return metricsAsync.when(
      loading: () => const SizedBox(height: 80, child: LoadingView()),
      error: (error, _) => ErrorView(error: error, compact: true),
      data: (metrics) {
        if (metrics.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.query_stats, size: 18, color: context.colors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No metrics collected yet. Turn on background monitoring '
                      'in Settings.',
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        String read(String collectorId, {bool asBytes = false}) {
          final match = metrics.where((m) => m.collectorId == collectorId);
          if (match.isEmpty) return '—';
          final metric = match.first;
          if (asBytes) {
            final bytes = int.tryParse(metric.value);
            if (bytes != null) return formatBytes(bytes);
          }
          return metric.value;
        }

        String unitOf(String collectorId) {
          final match = metrics.where((m) => m.collectorId == collectorId);
          return match.isEmpty ? '' : (match.first.unit ?? '');
        }

        final colors = context.colors;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Resources', style: context.text.titleMedium),
            ),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'CPU',
                    value: read('cpu_usage'),
                    unit: unitOf('cpu_usage'),
                    icon: Icons.memory,
                    color: context.scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricCard(
                    label: 'Memory',
                    value: read('memory_usage_pct'),
                    unit: unitOf('memory_usage_pct'),
                    icon: Icons.storage,
                    color: colors.info,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricCard(
                    label: 'Disk',
                    value: read('disk_usage_pct'),
                    unit: unitOf('disk_usage_pct'),
                    icon: Icons.disc_full,
                    color: colors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Memory total',
                    value: read('memory_total', asBytes: true),
                    icon: Icons.developer_board,
                    color: context.scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricCard(
                    label: 'Processes',
                    value: read('proc_running'),
                    icon: Icons.apps,
                    color: colors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricCard(
                    label: 'Failed units',
                    value: read('svc_failed'),
                    icon: Icons.error_outline,
                    color: colors.danger,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ConnectionInfo extends ConsumerWidget {
  const _ConnectionInfo({required this.host});

  final Host host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identities = ref.watch(identitiesProvider).valueOrNull ?? const [];
    final groups = ref.watch(groupsProvider).valueOrNull ?? const [];

    // Resolve to names — a raw UUID told the user nothing.
    final identityName = host.identityId == null
        ? 'None'
        : identities
            .where((i) => i.id == host.identityId)
            .map((i) => i.name)
            .firstOrDefault('Missing credential');

    final groupName = host.groupId == null
        ? 'Ungrouped'
        : groups.where((g) => g.id == host.groupId).map((g) => g.name).firstOrDefault('Unknown');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connection', style: context.text.titleMedium),
            const SizedBox(height: 12),
            _InfoRow(label: 'Hostname', value: host.hostname, mono: true),
            _InfoRow(label: 'Port', value: '${host.port}', mono: true),
            _InfoRow(label: 'Username', value: host.username, mono: true),
            _InfoRow(label: 'Credential', value: identityName),
            _InfoRow(label: 'Group', value: groupName),
            _InfoRow(
              label: 'Last seen',
              value: host.lastSeen?.timeAgo ?? 'Never',
            ),
            _InfoRow(
              label: 'Status',
              value: host.status,
              valueColor: context.colors.status(host.status),
            ),
            _InfoRow(
              label: 'Monitoring',
              value: host.monitoringPaused ? 'Paused' : 'Active',
              valueColor:
                  host.monitoringPaused ? context.colors.textMuted : context.colors.success,
            ),
            if (host.metadata.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Metadata', style: context.text.titleSmall),
              const SizedBox(height: 6),
              for (final entry in host.metadata.entries)
                _InfoRow(label: entry.key, value: entry.value, mono: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.host});

  final Host host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final canConnect = host.identityId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Actions', style: context.text.titleMedium),
        ),
        if (!canConnect)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.key_off_outlined, size: 18, color: colors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No credential is attached, so this host cannot be '
                      'reached. Edit it and pick one from the vault.',
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canConnect ? () => context.push('/hosts/${host.id}/terminal') : null,
                icon: const Icon(Icons.terminal, size: 18),
                label: const Text('Terminal'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canConnect ? () => context.push('/hosts/${host.id}/files') : null,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Files'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/hosts/${host.id}/monitoring'),
                icon: const Icon(Icons.monitor_heart_outlined, size: 18),
                label: const Text('Monitoring'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(hostListProvider.notifier).toggleFavorite(host.id);
                  ref.invalidate(hostDetailProvider(host.id));
                  ref.invalidate(hostsProvider);
                },
                icon: Icon(host.favorite ? Icons.star : Icons.star_border, size: 18),
                style: OutlinedButton.styleFrom(
                  foregroundColor: host.favorite ? colors.warning : null,
                ),
                label: Text(host.favorite ? 'Favourited' : 'Favourite'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await ref.read(hostListProvider.notifier).toggleMonitoringPaused(host.id);
              ref.invalidate(hostDetailProvider(host.id));
              ref.invalidate(hostsProvider);
              ref.invalidate(hostStatusCountsProvider);
            },
            icon: Icon(
              host.monitoringPaused ? Icons.play_circle_outline : Icons.pause_circle_outline,
              size: 18,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: host.monitoringPaused ? colors.warning : null,
            ),
            label: Text(
              host.monitoringPaused ? 'Resume monitoring' : 'Pause monitoring',
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            // Previously navigated to the edit screen instead of deleting.
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete host'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.danger,
              side: BorderSide(color: colors.danger.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${host.name}?'),
        content: const Text(
          'The host and its collected metrics are removed. Credentials in the '
          'vault are not affected. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(hostListProvider.notifier).removeHost(host.id);
    ref.invalidate(hostsProvider);
    ref.invalidate(hostStatusCountsProvider);

    if (context.mounted) context.pop();
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.colors.border),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(color: context.colors.textMuted),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: mono
                  ? AppTypography.monoSmall(valueColor ?? context.scheme.onSurface)
                  : context.text.bodyMedium?.copyWith(
                      color: valueColor ?? context.scheme.onSurface,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrDefault on Iterable<String> {
  String firstOrDefault(String fallback) => isEmpty ? fallback : first;
}
