import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/automation_run_repository.dart';
import '../modules/alerting/notification_service.dart';
import '../providers/providers.dart';
import '../ui/widgets/host_key_dialog.dart';
import 'settings/app_settings.dart';
import 'utils/logger.dart';

/// One-time wiring that runs after the first frame.
///
/// Deliberately not in `main()`: these steps depend on providers and on a
/// navigator being available, and none of them should be able to stop the app
/// from starting.
Future<void> runStartupTasks(Ref ref) async {
  // Any connection opened from anywhere gets the same host-key prompt, rather
  // than each screen remembering to install one — a screen that forgot would
  // silently refuse every unknown host.
  ref.read(connectionManagerProvider).onHostKeyPrompt = showHostKeyPrompt;

  final settings = ref.read(settingsProvider);

  try {
    await NotificationService.instance.initialize();
    NotificationService.instance.setEnabled(settings.alertNotifications);
  } catch (e) {
    logWarning('Notification setup skipped: $e');
  }

  try {
    // Runs interrupted by a crash or a force-quit would otherwise sit in the
    // history as permanently "running".
    await AutomationRunRepository().reconcileOrphans();
  } catch (e) {
    logWarning('Could not reconcile interrupted automation runs: $e');
  }

  if (settings.backgroundMonitoring) {
    try {
      await ref.read(monitoringServiceProvider).startMonitoring(
            interval: settings.monitoringInterval,
            retentionDays: settings.metricRetentionDays,
          );
      ref.read(isMonitoringProvider.notifier).state = true;
    } catch (e) {
      logWarning('Could not start monitoring: $e');
    }
  }
}

/// Fires the startup tasks exactly once per app launch.
final startupProvider = Provider<void>((ref) {
  unawaited(runStartupTasks(ref));
});
