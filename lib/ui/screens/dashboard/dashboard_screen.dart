import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/alert.dart';
import '../../../data/models/host.dart';
import '../../../data/models/incident.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/status_badge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add host',
            onPressed: () => context.push('/hosts/new'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(hostsProvider)
            ..invalidate(alertsProvider)
            ..invalidate(incidentsProvider)
            ..invalidate(hostStatusCountsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: const [
            _StatusOverview(),
            SizedBox(height: 20),
            _QuickActions(),
            SizedBox(height: 20),
            _AlertsSection(),
            SizedBox(height: 20),
            _IncidentsSection(),
            SizedBox(height: 20),
            _HostsSection(),
          ],
        ),
      ),
    );
  }
}

class _StatusOverview extends ConsumerWidget {
  const _StatusOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(hostStatusCountsProvider);
    final colors = context.colors;

    return counts.when(
      loading: () => const SizedBox(height: 90, child: LoadingView()),
      error: (error, _) => ErrorView(error: error, compact: true),
      data: (data) {
        final online = data['online'] ?? 0;
        final offline = data['offline'] ?? 0;
        final unknown = (data['unknown'] ?? 0) + (data['pending'] ?? 0);
        final total = data.values.fold<int>(0, (sum, value) => sum + value);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Fleet', style: context.text.titleMedium),
                    const Spacer(),
                    Text(
                      total == 1 ? '1 host' : '$total hosts',
                      style: context.text.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Stat(value: online, label: 'Online', color: colors.success),
                    _Stat(value: offline, label: 'Offline', color: colors.danger),
                    _Stat(value: unknown, label: 'Unknown', color: colors.textMuted),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: AppTypography.monoMetric(color)),
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

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Quick actions', style: context.text.titleMedium),
        ),
        Row(
          children: [
            _Action(
              icon: Icons.add,
              label: 'Add host',
              onTap: () => context.push('/hosts/new'),
            ),
            const SizedBox(width: 8),
            _Action(
              icon: Icons.key_outlined,
              label: 'Vault',
              onTap: () => context.go('/vault'),
            ),
            const SizedBox(width: 8),
            _Action(
              icon: Icons.play_circle_outline,
              label: 'Automation',
              onTap: () => context.push('/automation'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, size: 22, color: context.scheme.primary),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: context.text.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertsSection extends ConsumerWidget {
  const _AlertsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);

    return alerts.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return _Section(
          title: 'Active alerts (${items.length})',
          titleColor: context.colors.danger,
          onViewAll: () => context.push('/alerts'),
          child: Column(
            children: [
              for (final alert in items.take(4)) _AlertRow(alert: alert),
            ],
          ),
        );
      },
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.severity(alert.severity);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(width: 3, height: 28, color: color),
      title: Text(alert.name, style: context.text.bodyMedium),
      subtitle: Text(
        alert.message ?? alert.triggeredAt.timeAgo,
        style: context.text.labelSmall?.copyWith(color: context.colors.textMuted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _IncidentsSection extends ConsumerWidget {
  const _IncidentsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsProvider);

    return incidents.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (items) {
        final open = items.where((i) => i.isOpen).toList();
        if (open.isEmpty) return const SizedBox.shrink();

        return _Section(
          title: 'Open incidents (${open.length})',
          titleColor: context.colors.danger,
          onViewAll: () => context.push('/incidents'),
          child: Column(
            children: [
              for (final incident in open.take(3)) _IncidentRow(incident: incident),
            ],
          ),
        );
      },
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.bug_report_outlined,
        size: 20,
        color: context.colors.severity(incident.severity),
      ),
      title: Text(incident.title, style: context.text.bodyMedium),
      subtitle: Text(
        'Opened ${incident.createdAt.timeAgo}',
        style: context.text.labelSmall?.copyWith(color: context.colors.textMuted),
      ),
      onTap: () => context.push('/incidents/${incident.id}'),
    );
  }
}

class _HostsSection extends ConsumerWidget {
  const _HostsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hosts = ref.watch(hostsProvider);

    return hosts.when(
      loading: () => const SizedBox(height: 100, child: LoadingView()),
      error: (error, _) => ErrorView(error: error, compact: true),
      data: (items) {
        if (items.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.dns_outlined, size: 36, color: context.colors.textMuted),
                  const SizedBox(height: 12),
                  Text('No hosts yet', style: context.text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Add a server and attach a credential to start monitoring.',
                    style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push('/hosts/new'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add your first host'),
                  ),
                ],
              ),
            ),
          );
        }

        return _Section(
          title: 'Hosts',
          onViewAll: () => context.go('/hosts'),
          child: Column(
            children: [
              for (final host in items.take(5)) _HostRow(host: host),
            ],
          ),
        );
      },
    );
  }
}

class _HostRow extends StatelessWidget {
  const _HostRow({required this.host});

  final Host host;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.dns_outlined,
        size: 20,
        color: context.colors.status(host.status),
      ),
      title: Text(host.name, style: context.text.bodyMedium),
      subtitle: Text(
        host.endpoint,
        style: AppTypography.monoSmall(context.colors.textMuted),
      ),
      trailing: StatusBadge(status: host.status, fontSize: 10),
      onTap: () => context.push('/hosts/${host.id}'),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.titleColor,
    this.onViewAll,
  });

  final String title;
  final Widget child;
  final Color? titleColor;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: context.text.titleMedium?.copyWith(color: titleColor),
                  ),
                ),
                if (onViewAll != null)
                  TextButton(onPressed: onViewAll, child: const Text('View all')),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}
