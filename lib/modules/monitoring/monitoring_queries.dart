import '../../data/models/host.dart';
import '../../data/models/metric.dart';
import '../../data/repositories/metric_repository.dart';
import 'health_score.dart';
import 'monitoring_service.dart';

/// Reads of what collection has already stored.
extension MonitoringQueries on MonitoringService {
  /// One reading, on demand — the sweep is not involved.
  Future<List<Metric>> collectHostMetrics(Host host) => collector.collect(host);

  Future<List<Metric>> getLatestMetrics(String hostId) =>
      MetricRepository().getLatestForHost(hostId);

  Future<MetricSeries> getMetricSeries(String hostId, String collectorId) =>
      MetricRepository().getSeries(hostId, collectorId);

  Future<int> calculateHealthScore(String hostId) async =>
      HealthScore.fromMetrics(await getLatestMetrics(hostId));
}
