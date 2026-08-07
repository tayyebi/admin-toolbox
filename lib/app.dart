import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/settings/app_settings.dart';
import 'core/startup.dart';
import 'core/theme/app_theme.dart';
import 'ui/routes.dart';

class AdminToolboxApp extends ConsumerStatefulWidget {
  const AdminToolboxApp({super.key});

  @override
  ConsumerState<AdminToolboxApp> createState() => _AdminToolboxAppState();
}

class _AdminToolboxAppState extends ConsumerState<AdminToolboxApp> {
  @override
  void initState() {
    super.initState();
    // After the first frame, so the navigator the host-key dialog needs exists.
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(startupProvider));
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Admin Toolbox',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        // Pin text scaling to a sane range: terminal output and metric tables
        // stop being readable past roughly 130%.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
