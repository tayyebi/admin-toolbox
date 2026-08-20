import 'package:flutter/material.dart';

/// The bottom bar's five destinations. [alertCount] badges the Monitor tab, so
/// a firing alert stays visible from anywhere in the app.
List<NavigationDestination> shellDestinations(int alertCount) => [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.dns_outlined),
            selectedIcon: Icon(Icons.dns),
            label: 'Hosts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.key_outlined),
            selectedIcon: Icon(Icons.key),
            label: 'Vault',
          ),
          NavigationDestination(
            icon: alertCount > 0
                ? Badge(
                    label: Text('$alertCount'),
                    child: const Icon(Icons.monitor_heart_outlined),
                  )
                : const Icon(Icons.monitor_heart_outlined),
            selectedIcon: const Icon(Icons.monitor_heart),
            label: 'Monitor',
          ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
    ];
