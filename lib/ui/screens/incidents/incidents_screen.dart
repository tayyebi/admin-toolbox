import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';

class IncidentsScreen extends ConsumerWidget {
  const IncidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentsAsync = ref.watch(incidentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Incident',
            onPressed: () {},
          ),
        ],
      ),
      body: incidentsAsync.when(
        data: (incidents) {
          if (incidents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  const Text('No incidents', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  const Text('Track operational incidents here.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            );
          }

          final openIncidents = incidents.where((i) => i.status == 'open').toList();
          final resolvedIncidents = incidents.where((i) => i.status != 'open').toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(incidentsProvider),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (openIncidents.isNotEmpty) ...[
                  Text('Open (${openIncidents.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.dangerRed)),
                  const SizedBox(height: 8),
                  ...openIncidents.map((incident) => Card(
                        child: ListTile(
                          leading: Icon(Icons.bug_report, color: AppTheme.severityColor(incident.severity)),
                          title: Text(incident.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                          subtitle: Text(
                            '${incident.affectedHosts.length} hosts affected • ${incident.timeline.length} events',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
                if (resolvedIncidents.isNotEmpty) ...[
                  Text('Resolved (${resolvedIncidents.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.successGreen)),
                  const SizedBox(height: 8),
                  ...resolvedIncidents.map((incident) => Card(
                        child: ListTile(
                          leading: Icon(Icons.check_circle, color: AppTheme.severityColor(incident.severity).withValues(alpha: 0.5)),
                          title: Text(incident.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.textSecondary)),
                          subtitle: Text(
                            '${incident.affectedHosts.length} hosts',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                        ),
                      )),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
