import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/command.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';

/// Saved commands, grouped by category.
///
/// The model, repository and providers all existed; there was no screen, so
/// nothing could reach them.
class CommandsScreen extends ConsumerWidget {
  const CommandsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = ref.watch(commandsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Command library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/commands/new'),
          ),
        ],
      ),
      body: commands.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(commandsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.terminal_outlined,
              title: 'No saved commands',
              message: 'Save commands you run often. Use {{variables}} for the '
                  'parts that change.',
              actionLabel: 'Add command',
              onAction: () => context.push('/commands/new'),
            );
          }

          final byCategory = <String, List<Command>>{};
          for (final command in items) {
            byCategory.putIfAbsent(command.category ?? 'Uncategorised', () => []).add(command);
          }
          final categories = byCategory.keys.toList()..sort();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(commandsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: [
                for (final category in categories) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                    child: Text(
                      category.toUpperCase(),
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ...byCategory[category]!.map(
                    (command) => _CommandCard(command: command),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommandCard extends ConsumerWidget {
  const _CommandCard({required this.command});

  final Command command;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final placeholders = Command.placeholdersIn(command.command);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(command.name, style: context.text.titleMedium),
                ),
                IconButton(
                  tooltip: command.favorite ? 'Unstar' : 'Star',
                  icon: Icon(
                    command.favorite ? Icons.star : Icons.star_border,
                    size: 20,
                    color: command.favorite ? colors.warning : colors.textMuted,
                  ),
                  onPressed: () async {
                    await ref.read(commandRepositoryProvider).toggleFavorite(command.id);
                    ref.invalidate(commandsProvider);
                  },
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, size: 20, color: colors.textMuted),
                  onSelected: (action) async {
                    switch (action) {
                      case 'edit':
                        unawaited(context.push('/commands/${command.id}/edit'));
                      case 'copy':
                        await Clipboard.setData(ClipboardData(text: command.command));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied')),
                          );
                        }
                      case 'delete':
                        await ref.read(commandRepositoryProvider).delete(command.id);
                        ref.invalidate(commandsProvider);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'copy', child: Text('Copy')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: colors.danger)),
                    ),
                  ],
                ),
              ],
            ),
            if (command.description != null && command.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(command.description!, style: context.text.bodySmall),
            ],
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                command.command,
                style: AppTypography.monoStyle(size: 11, color: context.scheme.onSurface),
              ),
            ),
            if (placeholders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final name in placeholders)
                    Chip(
                      label: Text(name),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
