import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static const _kThemeMode = 'settings.themeMode';
  static const _kTerminalFontSize = 'settings.terminalFontSize';
  static const _kBackgroundMonitoring = 'settings.backgroundMonitoring';
  static const _kMonitoringInterval = 'settings.monitoringIntervalSeconds';
  static const _kMetricRetention = 'settings.metricRetentionDays';
  static const _kNotifications = 'settings.notificationsEnabled';
  static const _kAlertNotifications = 'settings.alertNotifications';
  static const _kBiometric = 'settings.biometricUnlock';
  static const _kAutoLock = 'settings.autoLockMinutes';
  static const _kBlockScreenshots = 'settings.blockScreenshots';

  static AppSettings _read(SharedPreferences prefs) {
    const defaults = AppSettings();
    return AppSettings(
      themeMode: _themeModeFromName(prefs.getString(_kThemeMode)),
      terminalFontSize: prefs.getDouble(_kTerminalFontSize) ?? defaults.terminalFontSize,
      backgroundMonitoring:
          prefs.getBool(_kBackgroundMonitoring) ?? defaults.backgroundMonitoring,
      monitoringInterval: Duration(
        seconds: prefs.getInt(_kMonitoringInterval) ?? defaults.monitoringInterval.inSeconds,
      ),
      metricRetentionDays: prefs.getInt(_kMetricRetention) ?? defaults.metricRetentionDays,
      notificationsEnabled: prefs.getBool(_kNotifications) ?? defaults.notificationsEnabled,
      alertNotifications: prefs.getBool(_kAlertNotifications) ?? defaults.alertNotifications,
      biometricUnlock: prefs.getBool(_kBiometric) ?? defaults.biometricUnlock,
      autoLockDelay: Duration(
        minutes: prefs.getInt(_kAutoLock) ?? defaults.autoLockDelay.inMinutes,
      ),
      blockScreenshots: prefs.getBool(_kBlockScreenshots) ?? defaults.blockScreenshots,
    );
  }

  static ThemeMode _themeModeFromName(String? name) {
    switch (name) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_kThemeMode, mode.name);
  }

  Future<void> setTerminalFontSize(double size) async {
    final clamped = size.clamp(9.0, 22.0);
    state = state.copyWith(terminalFontSize: clamped);
    await _prefs.setDouble(_kTerminalFontSize, clamped);
  }

  Future<void> setBackgroundMonitoring(bool enabled) async {
    state = state.copyWith(backgroundMonitoring: enabled);
    await _prefs.setBool(_kBackgroundMonitoring, enabled);
  }

  Future<void> setMonitoringInterval(Duration interval) async {
    state = state.copyWith(monitoringInterval: interval);
    await _prefs.setInt(_kMonitoringInterval, interval.inSeconds);
  }

  Future<void> setMetricRetentionDays(int days) async {
    state = state.copyWith(metricRetentionDays: days);
    await _prefs.setInt(_kMetricRetention, days);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _prefs.setBool(_kNotifications, enabled);
  }

  Future<void> setAlertNotifications(bool enabled) async {
    state = state.copyWith(alertNotifications: enabled);
    await _prefs.setBool(_kAlertNotifications, enabled);
  }

  Future<void> setBiometricUnlock(bool enabled) async {
    state = state.copyWith(biometricUnlock: enabled);
    await _prefs.setBool(_kBiometric, enabled);
  }

  Future<void> setAutoLockDelay(Duration delay) async {
    state = state.copyWith(autoLockDelay: delay);
    await _prefs.setInt(_kAutoLock, delay.inMinutes);
  }

  Future<void> setBlockScreenshots(bool enabled) async {
    state = state.copyWith(blockScreenshots: enabled);
    await _prefs.setBool(_kBlockScreenshots, enabled);
  }
}

final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(ref.watch(sharedPreferencesProvider));
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider.select((s) => s.themeMode));
});
