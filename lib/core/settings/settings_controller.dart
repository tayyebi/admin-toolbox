import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'settings_keys.dart';
import 'theme_mode_codec.dart';

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;


  static AppSettings _read(SharedPreferences prefs) {
    const defaults = AppSettings();
    return AppSettings(
      themeMode: themeModeFromName(prefs.getString(SettingsKeys.themeMode)),
      terminalFontSize: prefs.getDouble(SettingsKeys.terminalFontSize) ?? defaults.terminalFontSize,
      backgroundMonitoring:
          prefs.getBool(SettingsKeys.backgroundMonitoring) ?? defaults.backgroundMonitoring,
      monitoringInterval: Duration(
        seconds: prefs.getInt(SettingsKeys.monitoringInterval) ?? defaults.monitoringInterval.inSeconds,
      ),
      metricRetentionDays: prefs.getInt(SettingsKeys.metricRetention) ?? defaults.metricRetentionDays,
      notificationsEnabled: prefs.getBool(SettingsKeys.notifications) ?? defaults.notificationsEnabled,
      alertNotifications: prefs.getBool(SettingsKeys.alertNotifications) ?? defaults.alertNotifications,
      biometricUnlock: prefs.getBool(SettingsKeys.biometric) ?? defaults.biometricUnlock,
      autoLockDelay: Duration(
        minutes: prefs.getInt(SettingsKeys.autoLock) ?? defaults.autoLockDelay.inMinutes,
      ),
      blockScreenshots: prefs.getBool(SettingsKeys.blockScreenshots) ?? defaults.blockScreenshots,
    );
  }


  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(SettingsKeys.themeMode, mode.name);
  }

  Future<void> setTerminalFontSize(double size) async {
    final clamped = size.clamp(9.0, 22.0);
    state = state.copyWith(terminalFontSize: clamped);
    await _prefs.setDouble(SettingsKeys.terminalFontSize, clamped);
  }

  Future<void> setBackgroundMonitoring(bool enabled) async {
    state = state.copyWith(backgroundMonitoring: enabled);
    await _prefs.setBool(SettingsKeys.backgroundMonitoring, enabled);
  }

  Future<void> setMonitoringInterval(Duration interval) async {
    state = state.copyWith(monitoringInterval: interval);
    await _prefs.setInt(SettingsKeys.monitoringInterval, interval.inSeconds);
  }

  Future<void> setMetricRetentionDays(int days) async {
    state = state.copyWith(metricRetentionDays: days);
    await _prefs.setInt(SettingsKeys.metricRetention, days);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _prefs.setBool(SettingsKeys.notifications, enabled);
  }

  Future<void> setAlertNotifications(bool enabled) async {
    state = state.copyWith(alertNotifications: enabled);
    await _prefs.setBool(SettingsKeys.alertNotifications, enabled);
  }

  Future<void> setBiometricUnlock(bool enabled) async {
    state = state.copyWith(biometricUnlock: enabled);
    await _prefs.setBool(SettingsKeys.biometric, enabled);
  }

  Future<void> setAutoLockDelay(Duration delay) async {
    state = state.copyWith(autoLockDelay: delay);
    await _prefs.setInt(SettingsKeys.autoLock, delay.inMinutes);
  }

  Future<void> setBlockScreenshots(bool enabled) async {
    state = state.copyWith(blockScreenshots: enabled);
    await _prefs.setBool(SettingsKeys.blockScreenshots, enabled);
  }
}

final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(ref.watch(sharedPreferencesProvider));
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider.select((s) => s.themeMode));
});
