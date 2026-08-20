import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/alert.dart';
import '../../../modules/monitoring/collectors/collectors.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';

/// Active alerts and the rules that produce them.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Alerts'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Active'), Tab(text: 'Rules')],
          ),
        ),
        body: const TabBarView(
          children: [_ActiveAlertsTab(), _RulesTab()],
        ),
      ),
    );
  }
}

class _ActiveAlertsTab extends ConsumerWidget {
  const _ActiveAlertsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);

    return alerts.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(alertsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.check_circle_outline,
            title: 'No active alerts',
            message: 'Rules are evaluated after every metric collection.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(alertsProvider);
            ref.invalidate(activeAlertCountProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) => _AlertCard(alert: items[index]),
          ),
        );
      },
    );
  }
}

class _AlertCard extends ConsumerWidget {
  const _AlertCard({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final severityColor = colors.severity(alert.severity);
    final silenced = alert.silencedUntil != null &&
        DateTime.now().isBefore(alert.silencedUntil!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 32, color: severityColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.name, style: context.text.titleMedium),
                      Text(
                        '${alert.severity.capitalize} · ${alert.triggeredAt.timeAgo}',
                        style: context.text.labelSmall?.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (alert.acknowledged)
                  Icon(Icons.check, size: 18, color: colors.success),
                if (silenced)
                  Icon(Icons.notifications_off_outlined, size: 18, color: colors.textMuted),
              ],
            ),
            if (alert.message != null) ...[
              const SizedBox(height: 10),
              Text(alert.message!, style: context.text.bodySmall),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (!alert.acknowledged)
                  TextButton(
                    onPressed: () async {
                      await ref.read(alertRepositoryProvider).acknowledge(alert.id);
                      ref.invalidate(alertsProvider);
                    },
                    child: const Text('Acknowledge'),
                  ),
                TextButton(
                  onPressed: () => _silence(context, ref),
                  child: const Text('Silence'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await ref.read(alertRepositoryProvider).resolve(alert.id);
                    ref.invalidate(alertsProvider);
                    ref.invalidate(activeAlertCountProvider);
                  },
                  child: const Text('Resolve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _silence(BuildContext context, WidgetRef ref) async {
    final duration = await showModalBottomSheet<Duration>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [
              (label: '1 hour', duration: Duration(hours: 1)),
              (label: '4 hours', duration: Duration(hours: 4)),
              (label: '24 hours', duration: Duration(hours: 24)),
              (label: '1 week', duration: Duration(days: 7)),
            ])
              ListTile(
                title: Text(option.label),
                onTap: () => Navigator.pop(sheetContext, option.duration),
              ),
          ],
        ),
      ),
    );

    if (duration == null) return;
    await ref.read(alertRepositoryProvider).silence(alert.id, duration);
    ref.invalidate(alertsProvider);
  }
}

class _RulesTab extends ConsumerWidget {
  const _RulesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(alertRulesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editRule(context, ref),
        child: const Icon(Icons.add),
      ),
      body: rules.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(alertRulesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.rule,
              title: 'No alert rules',
              message: 'A rule watches one metric and fires when it crosses a '
                  'threshold.',
              actionLabel: 'Create rule',
              onAction: () => _editRule(context, ref),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final rule = items[index];
              return Card(
                child: SwitchListTile(
                  value: rule.enabled,
                  onChanged: (enabled) async {
                    await ref.read(alertRuleRepositoryProvider).toggle(rule.id, enabled);
                    ref.invalidate(alertRulesProvider);
                  },
                  title: Text(rule.name, style: context.text.titleMedium),
                  subtitle: Text(
                    '${rule.collectorId} ${rule.condition} ${rule.threshold} '
                    '· ${rule.severity}',
                    style: context.text.bodySmall,
                  ),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      await ref.read(alertRuleRepositoryProvider).delete(rule.id);
                      ref.invalidate(alertRulesProvider);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editRule(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final thresholdController = TextEditingController(text: '80');

    var collectorId = 'cpu_usage';
    var condition = '>';
    var severity = 'warning';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('New alert rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Rule name'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: collectorId,
                  decoration: const InputDecoration(labelText: 'Metric'),
                  items: [
                    for (final id in knownMetricIds)
                      DropdownMenuItem(value: id, child: Text(id)),
                  ],
                  onChanged: (value) => setState(() => collectorId = value!),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: condition,
                        decoration: const InputDecoration(labelText: 'When'),
                        items: const [
                          DropdownMenuItem(value: '>', child: Text('above')),
                          DropdownMenuItem(value: '<', child: Text('below')),
                          DropdownMenuItem(value: '==', child: Text('equals')),
                        ],
                        onChanged: (value) => setState(() => condition = value!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: thresholdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Threshold'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('Info')),
                    DropdownMenuItem(value: 'warning', child: Text('Warning')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (value) => setState(() => severity = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      final now = DateTime.now();
      await ref.read(alertRuleRepositoryProvider).insert(
            AlertRule(
              id: const Uuid().v4(),
              name: nameController.text.trim(),
              collectorId: collectorId,
              condition: condition,
              threshold: thresholdController.text.trim(),
              severity: severity,
              createdAt: now,
              updatedAt: now,
            ),
          );
      ref.invalidate(alertRulesProvider);
    }

    nameController.dispose();
    thresholdController.dispose();
  }
}
