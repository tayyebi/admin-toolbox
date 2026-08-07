import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/repositories/automation_run_repository.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';

final automationRunsProvider = FutureProvider<List<AutomationRun>>((ref) async {
  return AutomationRunRepository().getAll();
});

class AutomationScreen extends ConsumerWidget {
  const AutomationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Automation'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/automation/new'),
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Procedures'), Tab(text: 'History')],
          ),
        ),
        body: const TabBarView(children: [_ProceduresTab(), _HistoryTab()]),
      ),
    );
  }
}

class _ProceduresTab extends ConsumerWidget {
  const _ProceduresTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final automations = ref.watch(automationsProvider);

    return automations.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(automationsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.play_circle_outline,
            title: 'No procedures yet',
            message: 'A procedure is a sequence of commands you can run across '
                'many hosts, with rollback if a step fails.',
            actionLabel: 'Create procedure',
            onAction: () => context.push('/automation/new'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(automationsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final automation = items[index];
              final hasRollback =
                  automation.rollbackSteps != null && automation.rollbackSteps!.isNotEmpty;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(automation.name, style: context.text.titleMedium),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_horiz,
                                size: 20, color: context.colors.textMuted),
                            onSelected: (action) async {
                              switch (action) {
                                case 'edit':
                                  unawaited(
                                    context.push('/automation/${automation.id}/edit'),
                                  );
                                case 'delete':
                                  await ref
                                      .read(automationRepositoryProvider)
                                      .delete(automation.id);
                                  ref.invalidate(automationsProvider);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete',
                                    style: TextStyle(color: context.colors.danger)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (automation.description != null &&
                          automation.description!.isNotEmpty)
                        Text(automation.description!, style: context.text.bodySmall),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _Pill(
                            icon: Icons.list_alt,
                            label: '${automation.steps.length} steps',
                          ),
                          const SizedBox(width: 8),
                          if (hasRollback)
                            const _Pill(icon: Icons.undo, label: 'rollback'),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: () => context.push('/automation/${automation.id}/run'),
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Run'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(automationRunsProvider);

    return runs.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(automationRunsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            title: 'No runs yet',
            message: 'Every execution is recorded here with its per-host result.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(automationRunsProvider),
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: context.colors.border),
            itemBuilder: (context, index) {
              final run = items[index];
              final color = switch (run.status) {
                'succeeded' => context.colors.success,
                'failed' => context.colors.danger,
                'cancelled' || 'interrupted' => context.colors.warning,
                _ => context.colors.info,
              };

              return ListTile(
                leading: Icon(
                  run.dryRun ? Icons.science_outlined : Icons.play_circle_outline,
                  color: color,
                  size: 22,
                ),
                title: Text(run.automationName, style: context.text.titleMedium),
                subtitle: Text(
                  '${run.status} · ${run.hostIds.length} host'
                  '${run.hostIds.length == 1 ? '' : 's'} · ${run.startedAt.timeAgo}'
                  '${run.dryRun ? ' · dry run' : ''}',
                  style: context.text.bodySmall,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.colors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}
