import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database/database.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/logger.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        logError('Flutter error', details.exception, details.stack);
        if (kDebugMode) FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        logError('Uncaught platform error', error, stack);
        return true;
      };

      try {
        final prefs = await SharedPreferences.getInstance();
        await AppDatabase.instance.initialize();

        runApp(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: const AdminToolboxApp(),
          ),
        );
      } catch (e, stack) {
        // Without a database there is nothing the app can usefully do, but a
        // black screen tells the user nothing. Show what failed instead.
        logError('Startup failed', e, stack);
        runApp(_StartupFailureApp(error: e));
      }
    },
    (error, stack) => logError('Uncaught zone error', error, stack),
  );
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Toolbox',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Admin Toolbox could not start',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The local database could not be opened. Reinstalling the '
                    'app will clear it, but any stored hosts and credentials '
                    'will be lost.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SelectableText(
                    '$error',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
