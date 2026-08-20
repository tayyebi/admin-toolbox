import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/dashboard/dashboard_screen.dart';
import 'screens/hosts/hosts_list_screen.dart';
import 'screens/monitoring/monitoring_screen.dart';
import 'screens/more/more_screen.dart';
import 'screens/vault/vault_screen.dart';
import 'shell/app_shell.dart';

/// The bottom-navigation destinations, in order.
const shellRoutes = ['/dashboard', '/hosts', '/vault', '/monitoring', '/more'];

RouteBase shellRoute(GlobalKey<NavigatorState> navigatorKey) =>
    ShellRoute(
        navigatorKey: navigatorKey,
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
      );
