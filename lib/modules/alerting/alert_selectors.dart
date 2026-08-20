import '../../data/models/alert.dart';
import '../../data/models/metric.dart';

bool isAlertSilenced(Alert alert) {
  final until = alert.silencedUntil;
  return until != null && DateTime.now().isBefore(until);
}

/// The most recent reading for one collector, out of a mixed batch.
Metric? latestMetricFor(List<Metric> metrics, String collectorId) {
  Metric? latest;
  for (final metric in metrics) {
    if (metric.collectorId != collectorId) continue;
    if (latest == null || metric.timestamp.isAfter(latest.timestamp)) {
      latest = metric;
    }
  }
  return latest;
}
