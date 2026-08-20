import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database/database.dart';
import 'core/settings/app_settings.dart';
import 'core/utils/logger.dart';
import 'startup_failure_app.dart';

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
        runApp(StartupFailureApp(error: e));
      }
    },
    (error, stack) => logError('Uncaught zone error', error, stack),
  );
}
