import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/utils/logger.dart';
import '../../data/models/alert.dart';

/// Local notifications for alerts.
///
/// Deliberately local-only: pushing infrastructure alerts through a third-party
/// service would mean sending hostnames and failure details off the device,
/// which is the opposite of what this app promises.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _enabled = true;

  static const _channelId = 'admin_toolbox_alerts';
  static const _channelName = 'Infrastructure alerts';

  Future<void> initialize() async {
    if (_initialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    try {
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (e, stack) {
      logError('Notification setup failed', e, stack);
    }
  }

  /// Android 13+ will not deliver anything until the user grants this.
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;

    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  // ignore: avoid_positional_boolean_parameters
  void setEnabled(bool enabled) => _enabled = enabled;

  Future<void> showAlert(Alert alert) async {
    if (!_enabled) return;
    await initialize();
    if (!_initialized) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Threshold breaches detected on monitored hosts',
        importance: _importanceFor(alert.severity),
        priority: _priorityFor(alert.severity),
        styleInformation: BigTextStyleInformation(alert.message ?? ''),
      ),
    );

    try {
      await _plugin.show(
        // A stable id per alert keeps repeat notifications from stacking up.
        alert.id.hashCode & 0x7FFFFFFF,
        alert.name,
        alert.message ?? 'Threshold breached',
        details,
      );
    } catch (e) {
      logWarning('Could not show notification: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  static Importance _importanceFor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Importance.max;
      case 'warning':
      case 'high':
        return Importance.high;
      default:
        return Importance.defaultImportance;
    }
  }

  static Priority _priorityFor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Priority.max;
      case 'warning':
      case 'high':
        return Priority.high;
      default:
        return Priority.defaultPriority;
    }
  }
}
