import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/security/app_lock_controller.dart';
import 'host_routes.dart';
import 'more_routes.dart';
import 'route_not_found.dart';
import 'screens/auth/lock_screen.dart';
import 'screens/auth/vault_setup_screen.dart';
import 'shell_routes.dart';

export 'shell_routes.dart' show shellRoutes;

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Routes reachable while the vault is locked.
const _unauthenticatedRoutes = {'/unlock', '/setup'};

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
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: [
      GoRoute(path: '/setup', builder: (context, state) => const VaultSetupScreen()),
      GoRoute(path: '/unlock', builder: (context, state) => const LockScreen()),
      shellRoute(_shellNavigatorKey),
      ...hostRoutes,
      ...moreRoutes,
    ],
    errorBuilder: (context, state) => RouteNotFound(location: state.uri.toString()),
  );
});

String? _redirect(Ref ref, String location) {
  final isUnauthenticatedRoute = _unauthenticatedRoutes.contains(location);

  switch (ref.read(appLockProvider).status) {
    case VaultStatus.unknown:
      // Secure storage has not answered yet; hold on the lock screen rather
      // than flashing a host list that may be about to disappear.
      return isUnauthenticatedRoute ? null : '/unlock';
    case VaultStatus.needsSetup:
      return location == '/setup' ? null : '/setup';
    case VaultStatus.locked:
      return location == '/unlock' ? null : '/unlock';
    case VaultStatus.unlocked:
      return isUnauthenticatedRoute ? '/dashboard' : null;
  }
}
