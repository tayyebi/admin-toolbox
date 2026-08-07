import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/app_lock_controller.dart';
import '../../core/security/secure_display.dart';
import '../../core/settings/app_settings.dart';
import '../../providers/providers.dart';
import '../routes.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_applySecureFlag());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockProvider.notifier);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        lock.markBackgrounded();
      case AppLifecycleState.resumed:
        lock.applyAutoLock(ref.read(autoLockDelayProvider));
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _applySecureFlag() {
    return SecureDisplay.setSecure(ref.read(settingsProvider).blockScreenshots);
  }

  int _indexForLocation(String location) {
    final index = shellRoutes.indexWhere(
      (route) => location == route || location.startsWith('$route/'),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _indexForLocation(location);
    final activeAlerts = ref.watch(activeAlertCountProvider);
    final alertCount = activeAlerts.valueOrNull ?? 0;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          if (index == selectedIndex) return;
          context.go(shellRoutes[index]);
        },
        destinations: [
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
        ],
      ),
    );
  }
}
