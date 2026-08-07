import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/alert.dart';
import '../../../data/models/host.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';

class MonitoringScreen extends ConsumerWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMonitoring = ref.watch(isMonitoringProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring'),
        actions: [
          IconButton(
            tooltip: isMonitoring ? 'Stop collecting' : 'Start collecting',
            icon: Icon(isMonitoring ? Icons.pause_circle_outline : Icons.play_circle_outline),
            onPressed: () async {
              final monitoring = ref.read(monitoringServiceProvider);
              final settings = ref.read(settingsProvider);

              if (isMonitoring) {
                monitoring.stopMonitoring();
              } else {
                await monitoring.startMonitoring(
                  interval: settings.monitoringInterval,
                  retentionDays: settings.metricRetentionDays,
                );
              }
              ref.read(isMonitoringProvider.notifier).state = !isMonitoring;
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(hostStatusCountsProvider)
            ..invalidate(alertsProvider)
            ..invalidate(hostsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (!isMonitoring) const _IdleBanner(),
            const _FleetOverview(),
            const SizedBox(height: 20),
            const _AlertsList(),
            const SizedBox(height: 20),
            const _HostStatusList(),
          ],
        ),
      ),
    );
  }
}

class _IdleBanner extends StatelessWidget {
  const _IdleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.pause_circle_outline, size: 18, color: context.colors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Collection is stopped. Start it to gather metrics and evaluate '
              'alert rules.',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _FleetOverview extends ConsumerWidget {
  const _FleetOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(hostStatusCountsProvider);
    final colors = context.colors;

    return counts.when(
      loading: () => const SizedBox(height: 100, child: LoadingView()),
      error: (error, _) => ErrorView(error: error, compact: true),
      data: (data) {
        final total = data.values.fold<int>(0, (sum, value) => sum + value);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fleet status', style: context.text.titleMedium),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Indicator(label: 'Total', count: total, color: context.scheme.primary),
                    _Indicator(
                      label: 'Online',
                      count: data['online'] ?? 0,
                      color: colors.success,
                    ),
                    _Indicator(
                      label: 'Offline',
                      count: data['offline'] ?? 0,
                      color: colors.danger,
                    ),
                    _Indicator(
                      label: 'Unknown',
                      count: data['unknown'] ?? 0,
                      color: colors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$count', style: AppTypography.monoMetric(color)),
          const SizedBox(height: 4),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _AlertsList extends ConsumerWidget {
  const _AlertsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);

    return alerts.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => ErrorView(error: error, compact: true),
      data: (items) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Active alerts (${items.length})',
                      style: context.text.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/alerts'),
                    child: const Text('View all'),
                  ),
                ],
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 18, color: context.colors.success),
                      const SizedBox(width: 8),
                      Text('Nothing firing', style: context.text.bodySmall),
                    ],
                  ),
                )
              else
                for (final alert in items.take(5)) _AlertRow(alert: alert),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertRow extends ConsumerWidget {
  const _AlertRow({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = context.colors.severity(alert.severity);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(width: 3, height: 30, color: color),
      title: Text(alert.name, style: context.text.bodyMedium),
      subtitle: Text(
        alert.triggeredAt.timeAgo,
        style: context.text.labelSmall?.copyWith(color: context.colors.textMuted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Acknowledge',
            icon: Icon(Icons.check, size: 18, color: context.colors.success),
            onPressed: () async {
              await ref.read(alertRepositoryProvider).acknowledge(alert.id);
              ref.invalidate(alertsProvider);
            },
          ),
          IconButton(
            tooltip: 'Resolve',
            icon: Icon(Icons.done_all, size: 18, color: context.colors.textMuted),
            onPressed: () async {
              await ref.read(alertRepositoryProvider).resolve(alert.id);
              ref.invalidate(alertsProvider);
              ref.invalidate(activeAlertCountProvider);
            },
          ),
        ],
      ),
    );
  }
}

class _HostStatusList extends ConsumerWidget {
  const _HostStatusList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hosts = ref.watch(hostsProvider);

    return hosts.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => ErrorView(error: error, compact: true),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Host status', style: context.text.titleMedium),
                const SizedBox(height: 8),
                for (final host in items) _HostStatusRow(host: host),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HostStatusRow extends ConsumerWidget {
  const _HostStatusRow({required this.host});

  final Host host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = context.colors.status(host.status);
    final health = ref.watch(healthScoreProvider(host.id));

    return InkWell(
      onTap: () => context.push('/hosts/${host.id}/monitoring'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 5, spreadRadius: 1),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(host.name, style: context.text.bodyMedium),
                  Text(
                    host.endpoint,
                    style: AppTypography.monoSmall(context.colors.textMuted),
                  ),
                ],
              ),
            ),
            health.maybeWhen(
              orElse: () => const SizedBox.shrink(),
              data: (score) => Text(
                '$score',
                style: AppTypography.monoStyle(
                  size: 14,
                  weight: FontWeight.w600,
                  color: context.colors.health(score),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
