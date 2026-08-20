import 'package:go_router/go_router.dart';

import 'screens/alerts/alerts_screen.dart';
import 'screens/audit/audit_log_screen.dart';
import 'screens/automation/automation_form_screen.dart';
import 'screens/automation/automation_run_screen.dart';
import 'screens/automation/automation_screen.dart';
import 'screens/commands/command_form_screen.dart';
import 'screens/commands/commands_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/incidents/incident_detail_screen.dart';
import 'screens/incidents/incidents_screen.dart';
import 'screens/settings/settings_screen.dart';

/// Everything reached from the More tab.
final List<RouteBase> moreRoutes = [

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
];
