import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  static const _routes = [
    '/dashboard',
    '/hosts',
    '/groups',
    '/monitoring',
    '/settings',
  ];

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;

    final routeIndex = _routes.indexOf(currentRoute);
    if (routeIndex != -1 && routeIndex != _selectedIndex) {
      _selectedIndex = routeIndex;
    }

    final activeAlerts = ref.watch(activeAlertCountProvider);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          context.go(_routes[index]);
        },
        backgroundColor: AppTheme.bgCard,
        indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryBlue),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.computer_outlined),
            selectedIcon: Icon(Icons.computer, color: AppTheme.primaryBlue),
            label: 'Hosts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder, color: AppTheme.primaryBlue),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: activeAlerts.when(
              data: (count) => count > 0
                  ? Badge(
                      label: Text('$count'),
                      child: const Icon(Icons.monitor_heart_outlined),
                    )
                  : const Icon(Icons.monitor_heart_outlined),
              loading: () => const Icon(Icons.monitor_heart_outlined),
              error: (_, __) => const Icon(Icons.monitor_heart_outlined),
            ),
            selectedIcon: const Icon(Icons.monitor_heart, color: AppTheme.primaryBlue),
            label: 'Monitor',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppTheme.primaryBlue),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
