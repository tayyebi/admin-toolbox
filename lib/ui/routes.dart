import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/security/app_lock_controller.dart';
import 'screens/alerts/alerts_screen.dart';
import 'screens/audit/audit_log_screen.dart';
import 'screens/auth/lock_screen.dart';
import 'screens/auth/vault_setup_screen.dart';
import 'screens/automation/automation_form_screen.dart';
import 'screens/automation/automation_run_screen.dart';
import 'screens/automation/automation_screen.dart';
import 'screens/commands/command_form_screen.dart';
import 'screens/commands/commands_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/files/file_browser_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/hosts/host_detail_screen.dart';
import 'screens/hosts/host_form_screen.dart';
import 'screens/hosts/hosts_list_screen.dart';
import 'screens/incidents/incident_detail_screen.dart';
import 'screens/incidents/incidents_screen.dart';
import 'screens/monitoring/host_monitoring_screen.dart';
import 'screens/monitoring/monitoring_screen.dart';
import 'screens/more/more_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/terminal/terminal_screen.dart';
import 'screens/vault/identity_detail_screen.dart';
import 'screens/vault/identity_form_screen.dart';
import 'screens/vault/vault_screen.dart';
import 'shell/app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Routes reachable while the vault is locked.
const _unauthenticatedRoutes = {'/unlock', '/setup'};

/// Destinations in the bottom navigation bar, in order.
const shellRoutes = ['/dashboard', '/hosts', '/vault', '/monitoring', '/more'];

final routerProvider = Provider<GoRouter>((ref) {
  // GoRouter needs a Listenable to know when to re-run redirects. Bridging
  // through a ValueNotifier keeps the router itself stable, so navigation
  // history survives lock and unlock.
  final refresh = ValueNotifier<VaultStatus>(ref.read(appLockProvider).status);
  ref.onDispose(refresh.dispose);
  ref.listen<VaultStatus>(
    appLockProvider.select((s) => s.status),
    (_, next) => refresh.value = next,
  );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(appLockProvider).status;
      final location = state.matchedLocation;
      final isUnauthenticatedRoute = _unauthenticatedRoutes.contains(location);

      switch (status) {
        case VaultStatus.unknown:
          // Secure storage has not answered yet; hold on the lock screen
          // rather than flashing a host list that may be about to disappear.
          return isUnauthenticatedRoute ? null : '/unlock';
        case VaultStatus.needsSetup:
          return location == '/setup' ? null : '/setup';
        case VaultStatus.locked:
          return location == '/unlock' ? null : '/unlock';
        case VaultStatus.unlocked:
          return isUnauthenticatedRoute ? '/dashboard' : null;
      }
    },
    routes: [
      GoRoute(
        path: '/setup',
        builder: (context, state) => const VaultSetupScreen(),
      ),
      GoRoute(
        path: '/unlock',
        builder: (context, state) => const LockScreen(),
      ),

      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/hosts',
            pageBuilder: (context, state) => const NoTransitionPage(child: HostsListScreen()),
          ),
          GoRoute(
            path: '/vault',
            pageBuilder: (context, state) => const NoTransitionPage(child: VaultScreen()),
          ),
          GoRoute(
            path: '/monitoring',
            pageBuilder: (context, state) => const NoTransitionPage(child: MonitoringScreen()),
          ),
          GoRoute(
            path: '/more',
            pageBuilder: (context, state) => const NoTransitionPage(child: MoreScreen()),
          ),
        ],
      ),

      // Host detail and its tools sit above the shell so the bottom bar does
      // not compete with a full-screen terminal.
      GoRoute(
        path: '/hosts/new',
        builder: (context, state) => const HostFormScreen(),
      ),
      GoRoute(
        path: '/hosts/:id',
        builder: (context, state) => HostDetailScreen(hostId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => HostFormScreen(hostId: state.pathParameters['id']),
          ),
          GoRoute(
            path: 'monitoring',
            builder: (context, state) =>
                HostMonitoringScreen(hostId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'terminal',
            builder: (context, state) => TerminalScreen(hostId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'files',
            builder: (context, state) => FileBrowserScreen(hostId: state.pathParameters['id']!),
          ),
        ],
      ),

      GoRoute(
        path: '/vault/new',
        builder: (context, state) => const IdentityFormScreen(),
      ),
      GoRoute(
        path: '/vault/:id',
        builder: (context, state) => IdentityDetailScreen(identityId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                IdentityFormScreen(identityId: state.pathParameters['id']),
          ),
        ],
      ),

      GoRoute(path: '/groups', builder: (context, state) => const GroupsScreen()),
      GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
      GoRoute(path: '/audit', builder: (context, state) => const AuditLogScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),

      GoRoute(
        path: '/automation',
        builder: (context, state) => const AutomationScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const AutomationFormScreen(),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) =>
                AutomationFormScreen(automationId: state.pathParameters['id']),
          ),
          GoRoute(
            path: ':id/run',
            builder: (context, state) =>
                AutomationRunScreen(automationId: state.pathParameters['id']!),
          ),
        ],
      ),

      GoRoute(
        path: '/commands',
        builder: (context, state) => const CommandsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const CommandFormScreen(),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) => CommandFormScreen(commandId: state.pathParameters['id']),
          ),
        ],
      ),

      GoRoute(
        path: '/incidents',
        builder: (context, state) => const IncidentsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                IncidentDetailScreen(incidentId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _RouteNotFound(location: state.uri.toString()),
  );
});

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No screen matches $location', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Back to dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
