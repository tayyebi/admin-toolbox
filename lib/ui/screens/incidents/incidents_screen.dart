import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/incident.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';

class IncidentsScreen extends ConsumerWidget {
  const IncidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New incident',
            onPressed: () => _createIncident(context, ref),
          ),
        ],
      ),
      body: incidents.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(incidentsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.check_circle_outline,
              title: 'No incidents',
              message: 'Track outages and their resolution here.',
              actionLabel: 'New incident',
              onAction: () => _createIncident(context, ref),
            );
          }

          final open = items.where((i) => i.isOpen).toList();
          final closed = items.where((i) => !i.isOpen).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(incidentsProvider);
              ref.invalidate(openIncidentsCountProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: [
                if (open.isNotEmpty) ...[
                  _GroupHeader(label: 'Open', count: open.length, color: context.colors.danger),
                  ...open.map((incident) => _IncidentCard(incident: incident)),
                  const SizedBox(height: 16),
                ],
                if (closed.isNotEmpty) ...[
                  _GroupHeader(
                    label: 'Resolved',
                    count: closed.length,
                    color: context.colors.success,
                  ),
                  ...closed.map((incident) => _IncidentCard(incident: incident)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _createIncident(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var severity = 'medium';

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('New incident'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Title'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'What is happening?'),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
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

    if (created == true && titleController.text.trim().isNotEmpty) {
      final now = DateTime.now();
      final id = const Uuid().v4();

      await ref.read(incidentRepositoryProvider).insert(
            Incident(
              id: id,
              title: titleController.text.trim(),
              description: descriptionController.text.trim().isEmpty
                  ? null
                  : descriptionController.text.trim(),
              severity: severity,
              timeline: [
                IncidentTimelineEntry(
                  id: const Uuid().v4(),
                  action: 'opened',
                  description: 'Incident opened',
                  timestamp: now,
                ),
              ],
              createdAt: now,
              updatedAt: now,
            ),
          );

      await ref.read(auditRepositoryProvider).log(
            action: 'create',
            entityType: 'incident',
            entityId: id,
            details: titleController.text.trim(),
          );

      ref.invalidate(incidentsProvider);
      ref.invalidate(openIncidentsCountProvider);
    }

    titleController.dispose();
    descriptionController.dispose();
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        '$label ($count)',
        style: context.text.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final severityColor = colors.severity(incident.severity);

    return Card(
      child: ListTile(
        leading: Icon(
          incident.isOpen ? Icons.bug_report_outlined : Icons.check_circle_outline,
          color: incident.isOpen ? severityColor : colors.success,
        ),
        title: Text(
          incident.title,
          style: context.text.titleMedium?.copyWith(
            color: incident.isOpen ? context.scheme.onSurface : colors.textMuted,
          ),
        ),
        subtitle: Text(
          '${incident.severity.capitalize} · '
          '${incident.affectedHosts.length} host'
          '${incident.affectedHosts.length == 1 ? '' : 's'} · '
          '${incident.timeline.length} event'
          '${incident.timeline.length == 1 ? '' : 's'} · '
          '${incident.createdAt.timeAgo}',
          style: context.text.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => context.push('/incidents/${incident.id}'),
      ),
    );
  }
}
