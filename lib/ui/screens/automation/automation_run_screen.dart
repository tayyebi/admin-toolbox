import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/automation.dart';
import '../../../data/models/host.dart';
import '../../../modules/automation/automation_engine.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/host_key_dialog.dart';
import 'automation_screen.dart';

/// Pick hosts → fill parameters → confirm → watch it run.
class AutomationRunScreen extends ConsumerStatefulWidget {
  const AutomationRunScreen({super.key, required this.automationId});

  final String automationId;

  @override
  ConsumerState<AutomationRunScreen> createState() => _AutomationRunScreenState();
}

class _AutomationRunScreenState extends ConsumerState<AutomationRunScreen> {
  final _selectedHostIds = <String>{};
  final _parameterControllers = <String, TextEditingController>{};

  AutomationEngine? _engine;
  StreamSubscription<AutomationRunProgress>? _runSubscription;
  AutomationRunProgress? _progress;

  bool _running = false;
  bool _dryRun = false;

  @override
  void dispose() {
    unawaited(_runSubscription?.cancel());
    _engine?.cancel();
    for (final controller in _parameterControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Placeholders across every step, so the operator fills each one once.
  List<String> _parametersFor(Automation automation) {
    final names = <String>{};
    for (final step in [...automation.steps, ...?automation.rollbackSteps]) {
      names.addAll(RegExp(r'\{\{(\w+)\}\}')
          .allMatches(step.command)
          .map((match) => match.group(1)!));
    }
    return names.toList()..sort();
  }

  Future<void> _start(Automation automation, List<Host> allHosts) async {
    final hosts = allHosts.where((h) => _selectedHostIds.contains(h.id)).toList();
    if (hosts.isEmpty) return;

    final parameters = {
      for (final entry in _parameterControllers.entries) entry.key: entry.value.text,
    };

    if (!_dryRun) {
      final confirmed = await _confirm(automation, hosts);
      if (!confirmed) return;
    }

    ref.read(connectionManagerProvider).onHostKeyPrompt = showHostKeyPrompt;

    final engine = AutomationEngine();
    _engine = engine;

    setState(() => _running = true);

    _runSubscription = engine
        .run(
          automation: automation,
          hosts: hosts,
          parameters: parameters,
          dryRun: _dryRun,
        )
        .listen(
          (progress) => setState(() => _progress = progress),
          onDone: () {
            if (mounted) setState(() => _running = false);
            ref.invalidate(automationRunsProvider);
            ref.invalidate(auditLogProvider);
          },
          onError: (Object error) {
            if (mounted) {
              setState(() => _running = false);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Run failed: $error')));
            }
          },
        );
  }

  /// A procedure that restarts services across a fleet deserves one explicit
  /// confirmation naming what runs where.
  Future<bool> _confirm(Automation automation, List<Host> hosts) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Run this procedure?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${automation.steps.length} step'
              '${automation.steps.length == 1 ? '' : 's'} will run on '
              '${hosts.length} host${hosts.length == 1 ? '' : 's'}:',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: 8),
            ...hosts.take(6).map(
                  (host) => Text(
                    '· ${host.name} (${host.endpoint})',
                    style: AppTypography.monoSmall(context.colors.textMuted),
                  ),
                ),
            if (hosts.length > 6)
              Text(
                '· and ${hosts.length - 6} more',
                style: AppTypography.monoSmall(context.colors.textMuted),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Run'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final automationAsync = ref.watch(automationDetailProvider(widget.automationId));
    final hostsAsync = ref.watch(hostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(automationAsync.valueOrNull?.name ?? 'Run'),
        actions: [
          if (_running)
            TextButton(
              onPressed: () {
                _engine?.cancel();
                setState(() => _running = false);
              },
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: automationAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(error: error),
        data: (automation) {
          if (automation == null) {
            return const EmptyState(icon: Icons.search_off, title: 'Procedure not found');
          }

          return hostsAsync.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(error: error),
            data: (hosts) => _progress == null
                ? _buildSetup(automation, hosts)
                : _buildProgress(automation, hosts),
          );
        },
      ),
    );
  }

  Widget _buildSetup(Automation automation, List<Host> hosts) {
    final parameters = _parametersFor(automation);
    for (final name in parameters) {
      _parameterControllers.putIfAbsent(name, TextEditingController.new);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text('Target hosts', style: context.text.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Steps run on each host in turn.',
                style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
              ),
              const SizedBox(height: 8),

              if (hosts.isEmpty)
                const EmptyState(icon: Icons.dns_outlined, title: 'No hosts yet')
              else ...[
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(
                        () => _selectedHostIds.addAll(hosts.map((h) => h.id)),
                      ),
                      child: const Text('Select all'),
                    ),
                    TextButton(
                      onPressed: () => setState(_selectedHostIds.clear),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                ...hosts.map(
                  (host) => CheckboxListTile(
                    value: _selectedHostIds.contains(host.id),
                    onChanged: (selected) => setState(() {
                      if (selected ?? false) {
                        _selectedHostIds.add(host.id);
                      } else {
                        _selectedHostIds.remove(host.id);
                      }
                    }),
                    dense: true,
                    title: Text(host.name),
                    subtitle: Text(
                      host.endpoint,
                      style: AppTypography.monoSmall(context.colors.textMuted),
                    ),
                    secondary: host.identityId == null
                        ? Tooltip(
                            message: 'No credential attached',
                            child: Icon(Icons.key_off_outlined,
                                size: 18, color: context.colors.warning),
                          )
                        : null,
                  ),
                ),
              ],

              if (parameters.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Parameters', style: context.text.titleMedium),
                const SizedBox(height: 8),
                for (final name in parameters) ...[
                  TextField(
                    controller: _parameterControllers[name],
                    decoration: InputDecoration(labelText: name),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                ],
              ],

              const SizedBox(height: 8),
              SwitchListTile(
                value: _dryRun,
                onChanged: (value) => setState(() => _dryRun = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Dry run'),
                subtitle: Text(
                  'Show the exact commands with variables substituted, without '
                  'connecting or executing.',
                  style: context.text.bodySmall,
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _selectedHostIds.isEmpty ? null : () => _start(automation, hosts),
              icon: Icon(_dryRun ? Icons.science_outlined : Icons.play_arrow, size: 20),
              label: Text(
                _dryRun
                    ? 'Preview on ${_selectedHostIds.length} host(s)'
                    : 'Run on ${_selectedHostIds.length} host(s)',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgress(Automation automation, List<Host> hosts) {
    final progress = _progress!;

    return Column(
      children: [
        if (_running) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _Summary(
                label: 'Succeeded',
                value: '${progress.succeededCount}',
                color: context.colors.success,
              ),
              _Summary(
                label: 'Failed',
                value: '${progress.failedCount}',
                color: context.colors.danger,
              ),
              _Summary(
                label: 'Hosts',
                value: '${progress.results.length}',
                color: context.colors.info,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            itemCount: progress.results.length,
            itemBuilder: (context, index) => _HostResultCard(result: progress.results[index]),
          ),
        ),
        if (progress.finished)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () => setState(() => _progress = null),
                child: const Text('Run again'),
              ),
            ),
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTypography.monoMetric(color)),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HostResultCard extends StatelessWidget {
  const _HostResultCard({required this.result});

  final HostRunResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = result.succeeded
        ? colors.success
        : result.error != null
            ? colors.danger
            : colors.info;

    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          result.succeeded
              ? Icons.check_circle_outline
              : result.error != null
                  ? Icons.error_outline
                  : Icons.pending_outlined,
          color: color,
          size: 22,
        ),
        title: Text(result.hostName, style: context.text.titleMedium),
        subtitle: Text(
          result.error ??
              '${result.steps.length} step${result.steps.length == 1 ? '' : 's'}'
                  '${result.rolledBack ? ' · rolled back' : ''}',
          style: context.text.bodySmall,
        ),
        children: [
          for (final step in result.steps)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_iconFor(step.outcome), size: 14, color: _colorFor(context, step.outcome)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          step.command,
                          style: AppTypography.monoSmall(context.scheme.onSurface),
                        ),
                      ),
                      if (step.exitCode != null)
                        Text(
                          'exit ${step.exitCode}',
                          style: AppTypography.monoSmall(colors.textMuted),
                        ),
                    ],
                  ),
                  if (step.output.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        step.output.trim(),
                        style: AppTypography.monoStyle(size: 10, color: colors.textMuted),
                        maxLines: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static IconData _iconFor(StepOutcome outcome) => switch (outcome) {
        StepOutcome.succeeded => Icons.check,
        StepOutcome.failed => Icons.close,
        StepOutcome.running => Icons.more_horiz,
        StepOutcome.rolledBack => Icons.undo,
        StepOutcome.skipped => Icons.remove,
        StepOutcome.pending => Icons.schedule,
      };

  static Color _colorFor(BuildContext context, StepOutcome outcome) => switch (outcome) {
        StepOutcome.succeeded => context.colors.success,
        StepOutcome.failed => context.colors.danger,
        StepOutcome.rolledBack => context.colors.warning,
        _ => context.colors.textMuted,
      };
}
