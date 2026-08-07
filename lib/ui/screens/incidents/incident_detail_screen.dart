import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/incident.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';

class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentAsync = ref.watch(incidentDetailProvider(incidentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident'),
        actions: [
          incidentAsync.maybeWhen(
            data: (incident) => incident != null && incident.isOpen
                ? TextButton(
                    onPressed: () => _resolve(context, ref, incident),
                    child: const Text('Resolve'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: incidentAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(incidentDetailProvider(incidentId)),
        ),
        data: (incident) {
          if (incident == null) {
            return const EmptyState(icon: Icons.search_off, title: 'Incident not found');
          }
          return _Body(incident: incident);
        },
      ),
      floatingActionButton: incidentAsync.maybeWhen(
        data: (incident) => incident != null && incident.isOpen
            ? FloatingActionButton.extended(
                onPressed: () => _addTimelineEntry(context, ref, incident),
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Add update'),
              )
            : null,
        orElse: () => null,
      ),
    );
  }

  Future<void> _addTimelineEntry(
    BuildContext context,
    WidgetRef ref,
    Incident incident,
  ) async {
    final controller = TextEditingController();

    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add update'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'What changed?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (text == null || text.isEmpty) return;

    await ref.read(incidentRepositoryProvider).update(
          incident.copyWith(
            timeline: [
              ...incident.timeline,
              IncidentTimelineEntry(
                id: const Uuid().v4(),
                action: 'update',
                description: text,
                timestamp: DateTime.now(),
              ),
            ],
            updatedAt: DateTime.now(),
          ),
        );

    ref.invalidate(incidentDetailProvider(incidentId));
    ref.invalidate(incidentsProvider);
  }

  Future<void> _resolve(BuildContext context, WidgetRef ref, Incident incident) async {
    final controller = TextEditingController();

    final resolution = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resolve incident'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Resolution',
            hintText: 'What fixed it?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (resolution == null) return;

    // Record the closing note on the timeline as well as the resolution field,
    // so the history reads as a continuous account.
    await ref.read(incidentRepositoryProvider).update(
          incident.copyWith(
            timeline: [
              ...incident.timeline,
              IncidentTimelineEntry(
                id: const Uuid().v4(),
                action: 'resolved',
                description: resolution.isEmpty ? 'Resolved' : resolution,
                timestamp: DateTime.now(),
              ),
            ],
          ),
        );
    await ref.read(incidentRepositoryProvider).resolve(incident.id, resolution);
    await ref.read(auditRepositoryProvider).log(
          action: 'resolve',
          entityType: 'incident',
          entityId: incident.id,
          details: incident.title,
        );

    ref.invalidate(incidentDetailProvider(incidentId));
    ref.invalidate(incidentsProvider);
    ref.invalidate(openIncidentsCountProvider);

    if (context.mounted) context.pop();
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final hosts = ref.watch(hostsProvider).valueOrNull ?? const [];
    final affected =
        hosts.where((host) => incident.affectedHosts.contains(host.id)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.severity(incident.severity).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        incident.severity.toUpperCase(),
                        style: context.text.labelSmall?.copyWith(
                          color: colors.severity(incident.severity),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      incident.isOpen ? 'Open' : 'Resolved',
                      style: context.text.labelSmall?.copyWith(
                        color: incident.isOpen ? colors.danger : colors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(incident.title, style: context.text.headlineSmall),
                if (incident.description != null) ...[
                  const SizedBox(height: 8),
                  Text(incident.description!, style: context.text.bodyMedium),
                ],
                const SizedBox(height: 12),
                Text(
                  'Opened ${incident.createdAt.timeAgo}'
                  '${incident.resolvedAt != null ? ' · resolved ${incident.resolvedAt!.timeAgo}' : ''}',
                  style: context.text.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ),

        if (incident.resolution != null && incident.resolution!.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resolution', style: context.text.titleSmall),
                  const SizedBox(height: 6),
                  Text(incident.resolution!, style: context.text.bodyMedium),
                ],
              ),
            ),
          ),

        if (affected.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Affected hosts', style: context.text.titleSmall),
                  const SizedBox(height: 8),
                  ...affected.map(
                    (host) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.dns_outlined, size: 18),
                      title: Text(host.name),
                      subtitle: Text(host.endpoint),
                      onTap: () => context.push('/hosts/${host.id}'),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 8),
        Text('Timeline', style: context.text.titleMedium),
        const SizedBox(height: 12),

        if (incident.timeline.isEmpty)
          Text(
            'No updates recorded.',
            style: context.text.bodySmall?.copyWith(color: colors.textMuted),
          )
        else
          ...[
            for (var i = 0; i < incident.timeline.length; i++)
              _TimelineRow(
                entry: incident.timeline[i],
                isLast: i == incident.timeline.length - 1,
              ),
          ],
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.isLast});

  final IncidentTimelineEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (entry.action) {
      'opened' => colors.danger,
      'resolved' => colors.success,
      _ => colors.info,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(child: Container(width: 1.5, color: colors.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.action.capitalize,
                    style: context.text.titleSmall?.copyWith(color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(entry.description, style: context.text.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    entry.timestamp.timeAgo,
                    style: context.text.labelSmall?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
