import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'settings_controller.dart';
export 'settings_keys.dart';

/// User preferences, persisted to [SharedPreferences].
///
/// Nothing secret lives here — credentials and the vault key go through
/// `flutter_secure_storage` instead.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.terminalFontSize = 13,
    this.backgroundMonitoring = false,
    this.monitoringInterval = const Duration(seconds: 60),
    this.metricRetentionDays = 7,
    this.notificationsEnabled = true,
    this.alertNotifications = true,
    this.biometricUnlock = false,
    this.autoLockDelay = const Duration(minutes: 5),
    this.blockScreenshots = true,
  });

  final ThemeMode themeMode;
  final double terminalFontSize;
  final bool backgroundMonitoring;
  final Duration monitoringInterval;
  final int metricRetentionDays;
  final bool notificationsEnabled;
  final bool alertNotifications;
  final bool biometricUnlock;

  /// How long the app may sit in the background before the vault re-locks.
  /// [Duration.zero] locks immediately.
  final Duration autoLockDelay;

  /// Sets `FLAG_SECURE`, keeping the app out of the task-switcher preview.
  final bool blockScreenshots;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? terminalFontSize,
    bool? backgroundMonitoring,
    Duration? monitoringInterval,
    int? metricRetentionDays,
    bool? notificationsEnabled,
    bool? alertNotifications,
    bool? biometricUnlock,
    Duration? autoLockDelay,
    bool? blockScreenshots,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      terminalFontSize: terminalFontSize ?? this.terminalFontSize,
      backgroundMonitoring: backgroundMonitoring ?? this.backgroundMonitoring,
      monitoringInterval: monitoringInterval ?? this.monitoringInterval,
      metricRetentionDays: metricRetentionDays ?? this.metricRetentionDays,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      alertNotifications: alertNotifications ?? this.alertNotifications,
      biometricUnlock: biometricUnlock ?? this.biometricUnlock,
      autoLockDelay: autoLockDelay ?? this.autoLockDelay,
      blockScreenshots: blockScreenshots ?? this.blockScreenshots,
    );
  }
}

/// Overridden in `main()` once [SharedPreferences] has loaded, so the rest of
/// the app can read settings synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});
