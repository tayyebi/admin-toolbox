import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/app_lock_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/providers.dart';

/// The sections that do not earn a permanent slot in a five-item bottom bar.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openIncidents = ref.watch(openIncidentsCountProvider).valueOrNull ?? 0;
    final activeAlerts = ref.watch(activeAlertCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _Section(
            title: 'Operations',
            children: [
              _Entry(
                icon: Icons.notifications_active_outlined,
                label: 'Alerts',
                badge: activeAlerts > 0 ? '$activeAlerts' : null,
                onTap: () => context.push('/alerts'),
              ),
              _Entry(
                icon: Icons.report_problem_outlined,
                label: 'Incidents',
                badge: openIncidents > 0 ? '$openIncidents' : null,
                onTap: () => context.push('/incidents'),
              ),
              _Entry(
                icon: Icons.play_circle_outline,
                label: 'Automation',
                onTap: () => context.push('/automation'),
              ),
              _Entry(
                icon: Icons.terminal_outlined,
                label: 'Command library',
                onTap: () => context.push('/commands'),
              ),
            ],
          ),
          _Section(
            title: 'Inventory',
            children: [
              _Entry(
                icon: Icons.folder_outlined,
                label: 'Groups',
                onTap: () => context.push('/groups'),
              ),
            ],
          ),
          _Section(
            title: 'Security',
            children: [
              _Entry(
                icon: Icons.receipt_long_outlined,
                label: 'Audit log',
                onTap: () => context.push('/audit'),
              ),
              _Entry(
                icon: Icons.lock_outline,
                label: 'Lock now',
                onTap: () => ref.read(appLockProvider.notifier).lock(),
              ),
            ],
          ),
          _Section(
            title: 'App',
            children: [
              _Entry(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: context.text.labelSmall?.copyWith(
              color: context.colors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label, style: context.text.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: context.colors.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge!,
                style: context.text.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 18, color: context.colors.textMuted),
        ],
      ),
      onTap: onTap,
    );
  }
}
