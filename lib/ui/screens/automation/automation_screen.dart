import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';

class AutomationScreen extends ConsumerWidget {
  const AutomationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final automationsAsync = ref.watch(automationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Automation'),
      ),
      body: automationsAsync.when(
        data: (automations) {
          if (automations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline, size: 64, color: AppTheme.textMuted),
                  SizedBox(height: 16),
                  Text('No automations created', style: TextStyle(color: AppTheme.textSecondary)),
                  SizedBox(height: 8),
                  Text('Create reusable operational procedures\nthat can be executed across hosts.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted), textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: automations.length,
            itemBuilder: (context, index) {
              final automation = automations[index];
              return Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_circle, color: AppTheme.successGreen),
                  ),
                  title: Text(automation.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: automation.description != null && automation.description!.isNotEmpty
                      ? Text(automation.description!, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))
                      : null,
                  trailing: Text(
                    '${(automation.steps as List).length} steps',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
