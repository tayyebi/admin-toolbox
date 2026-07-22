import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'ui/shell/app_shell.dart';
import 'ui/screens/dashboard/dashboard_screen.dart';
import 'ui/screens/hosts/hosts_list_screen.dart';
import 'ui/screens/hosts/host_detail_screen.dart';
import 'ui/screens/hosts/host_form_screen.dart';
import 'ui/screens/groups/groups_screen.dart';
import 'ui/screens/monitoring/monitoring_screen.dart';
import 'ui/screens/monitoring/host_monitoring_screen.dart';
import 'ui/screens/terminal/terminal_screen.dart';
import 'ui/screens/files/file_browser_screen.dart';
import 'ui/screens/settings/settings_screen.dart';
import 'ui/screens/automation/automation_screen.dart';
import 'ui/screens/incidents/incidents_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/hosts',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HostsListScreen(),
          ),
          routes: [
            GoRoute(
              path: 'new',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const HostFormScreen(),
            ),
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => HostDetailScreen(
                hostId: state.pathParameters['id']!,
              ),
              routes: [
                GoRoute(
                  path: 'edit',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => HostFormScreen(
                    hostId: state.pathParameters['id'],
                  ),
                ),
                GoRoute(
                  path: 'monitoring',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => HostMonitoringScreen(
                    hostId: state.pathParameters['id']!,
                  ),
                ),
                GoRoute(
                  path: 'terminal',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => TerminalScreen(
                    hostId: state.pathParameters['id']!,
                  ),
                ),
                GoRoute(
                  path: 'files',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => FileBrowserScreen(
                    hostId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/groups',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GroupsScreen(),
          ),
        ),
        GoRoute(
          path: '/monitoring',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MonitoringScreen(),
          ),
        ),
        GoRoute(
          path: '/automation',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AutomationScreen(),
          ),
        ),
        GoRoute(
          path: '/incidents',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: IncidentsScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),
  ],
);
