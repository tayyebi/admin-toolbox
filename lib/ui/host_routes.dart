import 'package:go_router/go_router.dart';

import 'screens/files/file_browser_screen.dart';
import 'screens/hosts/host_detail_screen.dart';
import 'screens/hosts/host_form_screen.dart';
import 'screens/monitoring/host_monitoring_screen.dart';
import 'screens/terminal/terminal_screen.dart';
import 'screens/vault/identity_detail_screen.dart';
import 'screens/vault/identity_form_screen.dart';

/// Host detail and its tools sit above the shell so the bottom bar does not
/// compete with a full-screen terminal. The vault detail routes follow it.
final List<RouteBase> hostRoutes = [
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
];
