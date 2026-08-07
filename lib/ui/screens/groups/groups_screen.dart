import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/group.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final hosts = ref.watch(hostsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _editGroup(context, ref),
          ),
        ],
      ),
      body: groups.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(groupsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.folder_open,
              title: 'No groups yet',
              message: 'Group hosts by role, environment or location to run '
                  'procedures across them at once.',
              actionLabel: 'Create group',
              onAction: () => _editGroup(context, ref),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupsProvider);
              ref.invalidate(hostsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final group = items[index];
                final memberCount = hosts.where((h) => h.groupId == group.id).length;

                return Card(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.folder, color: context.scheme.primary, size: 20),
                    ),
                    title: Text(group.name, style: context.text.titleMedium),
                    subtitle: Text(
                      [
                        if (group.description != null && group.description!.isNotEmpty)
                          group.description!,
                        memberCount == 1 ? '1 host' : '$memberCount hosts',
                      ].join(' · '),
                      style: context.text.bodySmall,
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, size: 20, color: context.colors.textMuted),
                      // The menu previously had no onSelected, so neither entry
                      // did anything.
                      onSelected: (action) async {
                        switch (action) {
                          case 'edit':
                            await _editGroup(context, ref, existing: group);
                          case 'delete':
                            await _deleteGroup(context, ref, group, memberCount);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: context.colors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _editGroup(
    BuildContext context,
    WidgetRef ref, {
    Group? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing != null ? 'Edit group' : 'New group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              textCapitalization: TextCapitalization.sentences,
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
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    nameController.dispose();
    descriptionController.dispose();

    if (saved != true || name.isEmpty) return;

    final repo = ref.read(groupRepositoryProvider);
    final now = DateTime.now();

    if (existing != null) {
      await repo.update(
        existing.copyWith(
          name: name,
          description: description.isEmpty ? null : description,
          updatedAt: now,
        ),
      );
    } else {
      await repo.insert(
        Group(
          id: const Uuid().v4(),
          name: name,
          description: description.isEmpty ? null : description,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    ref.invalidate(groupsProvider);
  }

  Future<void> _deleteGroup(
    BuildContext context,
    WidgetRef ref,
    Group group,
    int memberCount,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${group.name}?'),
        content: Text(
          memberCount == 0
              ? 'This cannot be undone.'
              : '$memberCount host${memberCount == 1 ? '' : 's'} will become '
                  'ungrouped. The hosts themselves are not deleted.',
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

    await ref.read(groupRepositoryProvider).delete(group.id);
    ref.invalidate(groupsProvider);
    ref.invalidate(hostsProvider);
  }
}
