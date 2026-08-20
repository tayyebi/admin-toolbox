/// SharedPreferences keys. Nothing here is secret — secrets live in the vault.
abstract final class SettingsKeys {
  static const themeMode = 'settings.themeMode';
  static const terminalFontSize = 'settings.terminalFontSize';
  static const backgroundMonitoring = 'settings.backgroundMonitoring';
  static const monitoringInterval = 'settings.monitoringIntervalSeconds';
  static const metricRetention = 'settings.metricRetentionDays';
  static const notifications = 'settings.notificationsEnabled';
  static const alertNotifications = 'settings.alertNotifications';
  static const biometric = 'settings.biometricUnlock';
  static const autoLock = 'settings.autoLockMinutes';
  static const blockScreenshots = 'settings.blockScreenshots';
}
