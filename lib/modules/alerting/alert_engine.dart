import 'package:uuid/uuid.dart';

import '../../core/utils/logger.dart';
import '../../data/models/alert.dart';
import '../../data/models/host.dart';
import '../../data/models/metric.dart';
import '../../data/repositories/alert_repository.dart';
import 'notification_service.dart';

/// Evaluates alert rules against freshly collected metrics.
///
/// The rules table and the alert actions existed already; nothing evaluated
/// them, so no alert was ever raised. Three behaviours matter here and none of
/// them are optional in practice:
///
///  * **Deduplication** — a CPU stuck at 95% must produce one alert, not one
///    per collection cycle every minute.
///  * **Auto-resolution** — when the metric recovers, the alert closes itself.
///  * **Silencing** — a silenced alert stays silent until its window expires.
class AlertEngine {
  AlertEngine({
    AlertRepository? alerts,
    AlertRuleRepository? rules,
    NotificationService? notifications,
  })  : _alerts = alerts ?? AlertRepository(),
        _rules = rules ?? AlertRuleRepository(),
        _notifications = notifications ?? NotificationService.instance;

  final AlertRepository _alerts;
  final AlertRuleRepository _rules;
  final NotificationService _notifications;
  final _uuid = const Uuid();

  /// Checks one host's metrics and raises, holds or resolves alerts.
  Future<List<Alert>> evaluate({
    required Host host,
    required List<Metric> metrics,
    bool notify = true,
  }) async {
    final rules = (await _rules.getAll()).where((r) => r.enabled).toList();
    if (rules.isEmpty) return const [];

    final active = await _alerts.getAll(status: 'active', hostId: host.id);
    final raised = <Alert>[];

    for (final rule in rules) {
      final metric = _latestFor(metrics, rule.collectorId);
      if (metric == null) continue;

      final value = metric.numericValue;
      if (value == null) continue;

      final threshold = double.tryParse(rule.threshold);
      if (threshold == null) {
        logWarning('Alert rule ${rule.name} has a non-numeric threshold');
        continue;
      }

      final breached = _evaluateCondition(rule.condition, value, threshold);
      final existing = _findExisting(active, rule.id);

      if (breached && existing == null) {
        final alert = Alert(
          id: _uuid.v4(),
          name: rule.name,
          hostId: host.id,
          ruleId: rule.id,
          condition: rule.condition,
          threshold: rule.threshold,
          severity: rule.severity,
          triggeredAt: DateTime.now(),
          message: '${host.name}: ${rule.collectorId} is '
              '${value.toStringAsFixed(1)} (${rule.condition} ${rule.threshold})',
        );

        await _alerts.insert(alert);
        raised.add(alert);

        if (notify && !_isSilenced(alert)) {
          await _notifications.showAlert(alert);
        }
      } else if (!breached && existing != null) {
        // Recovered — close it rather than leaving a stale red badge.
        await _alerts.resolve(existing.id);
        logInfo('Alert "${rule.name}" resolved for ${host.name}');
      }
      // breached && existing != null → already open; deliberately no-op.
    }

    return raised;
  }

  Alert? _findExisting(List<Alert> active, String ruleId) {
    for (final alert in active) {
      if (alert.ruleId == ruleId) return alert;
    }
    return null;
  }

  static bool _isSilenced(Alert alert) {
    final until = alert.silencedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  static Metric? _latestFor(List<Metric> metrics, String collectorId) {
    Metric? latest;
    for (final metric in metrics) {
      if (metric.collectorId != collectorId) continue;
      if (latest == null || metric.timestamp.isAfter(latest.timestamp)) {
        latest = metric;
      }
    }
    return latest;
  }

  /// Supports the operators an alert rule can express.
  static bool _evaluateCondition(String condition, double value, double threshold) {
    switch (condition.trim()) {
      case '>':
      case 'gt':
      case 'above':
        return value > threshold;
      case '>=':
      case 'gte':
        return value >= threshold;
      case '<':
      case 'lt':
      case 'below':
        return value < threshold;
      case '<=':
      case 'lte':
        return value <= threshold;
      case '==':
      case 'eq':
      case 'equals':
        return value == threshold;
      case '!=':
      case 'ne':
        return value != threshold;
      default:
        logWarning('Unknown alert condition "$condition"; treating as no-op');
        return false;
    }
  }

  /// Exposed for tests and for the rule editor's live preview.
  static bool testCondition(String condition, double value, double threshold) =>
      _evaluateCondition(condition, value, threshold);
}
