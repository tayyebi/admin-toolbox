import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/metric.dart';
import '../modules/monitoring/monitoring_service.dart';
import 'repository_providers.dart';
import 'service_providers.dart';

// --- metrics ---------------------------------------------------------------

final hostMetricsProvider = FutureProvider.family<List<Metric>, String>((ref, hostId) async {
  return ref.watch(metricRepositoryProvider).getLatestForHost(hostId);
});

final metricSeriesProvider = FutureProvider.family<MetricSeries, ({String hostId, String collectorId})>(
  (ref, params) async {
    return ref.watch(metricRepositoryProvider).getSeries(params.hostId, params.collectorId);
  },
);

final healthScoreProvider = FutureProvider.family<int, String>((ref, hostId) async {
  return ref.watch(monitoringServiceProvider).calculateHealthScore(hostId);
});

final isMonitoringProvider = StateProvider<bool>((ref) => false);
