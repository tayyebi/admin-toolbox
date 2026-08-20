import 'package:uuid/uuid.dart';

import '../../core/utils/logger.dart';
import '../../data/models/alert.dart';
import '../../data/models/host.dart';
import '../../data/models/metric.dart';
import '../../data/repositories/alert_repository.dart';
import 'alert_condition.dart';
import 'alert_selectors.dart';
import 'notification_service.dart';

export 'alert_condition.dart';
export 'alert_selectors.dart';

/// Evaluates alert rules against freshly collected metrics.
///
/// Three behaviours matter and none are optional in practice: **deduplication**
/// (a CPU stuck at 95% raises one alert, not one per cycle), **auto-resolution**
/// (the alert closes itself when the metric recovers), and **silencing**.
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
      final metric = latestMetricFor(metrics, rule.collectorId);
      if (metric == null) continue;

      final value = metric.numericValue;
      if (value == null) continue;

      final threshold = double.tryParse(rule.threshold);
      if (threshold == null) {
        logWarning('Alert rule ${rule.name} has a non-numeric threshold');
        continue;
      }

      final breached = evaluateAlertCondition(rule.condition, value, threshold);
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

        if (notify && !isAlertSilenced(alert)) {
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
}
