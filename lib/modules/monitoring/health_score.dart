import '../../data/models/metric.dart';

/// A 0-100 summary of a host's current state.
///
/// Deductions are keyed by subsystem so a single overloaded subsystem is
/// counted once, however many metrics report it.
abstract final class HealthScore {
  static int fromMetrics(List<Metric> metrics) {
    if (metrics.isEmpty) return 0;

    final deductions = <String, double>{};

    for (final metric in metrics) {
      final value = metric.numericValue;
      if (value == null) continue;

      switch (metric.collectorId) {
        case 'cpu_usage':
          deductions['cpu'] = _tiered(value, {90: 15, 75: 8, 60: 3});
        case 'memory_usage_pct':
          deductions['memory'] = _tiered(value, {95: 20, 85: 10, 75: 5});
        case 'disk_usage_pct':
          deductions['disk'] = _tiered(value, {95: 15, 85: 8});
        case 'svc_failed':
          if (value > 0) deductions['services'] = (value * 5).clamp(0, 25);
        case 'proc_zombies':
          deductions['zombies'] = _tiered(value, {10: 10, 0: 3});
      }
    }

    final total = deductions.values.fold<double>(0, (sum, value) => sum + value);
    return (100 - total).clamp(0, 100).round();
  }

  /// The penalty for the highest threshold [value] exceeds.
  static double _tiered(double value, Map<int, double> thresholds) {
    final ordered = thresholds.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final threshold in ordered) {
      if (value > threshold) return thresholds[threshold]!;
    }
    return 0;
  }
}
