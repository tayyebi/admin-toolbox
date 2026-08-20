import '../../core/utils/logger.dart';
import '../../data/repositories/metric_repository.dart';

/// Ages out old readings.
///
/// The metrics table previously grew without bound; a busy fleet fills the
/// device eventually.
class MetricRetention {
  MetricRetention({MetricRepository? metrics}) : _metrics = metrics ?? MetricRepository();

  final MetricRepository _metrics;

  int days = 7;

  Future<int> purge() async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final deleted = await _metrics.deleteOlderThan(cutoff);
      if (deleted > 0) logInfo('Purged $deleted metric rows older than $days days');
      return deleted;
    } catch (e) {
      logWarning('Metric purge failed: $e');
      return 0;
    }
  }
}
