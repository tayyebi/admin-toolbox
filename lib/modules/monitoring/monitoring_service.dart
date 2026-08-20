import 'dart:async';

import '../../core/utils/logger.dart';
import '../../data/repositories/host_repository.dart';
import '../../data/transport/connection_manager.dart';
import 'collectors/collectors.dart';
import 'host_metric_collector.dart';
import 'metric_retention.dart';

export 'health_score.dart';
export 'host_metric_collector.dart';
export 'metric_retention.dart';
export 'monitoring_queries.dart';

/// The periodic sweep: which hosts get read and how often. What one reading
/// involves is [HostMetricCollector]'s; ageing them out is [MetricRetention]'s.
class MonitoringService {
  MonitoringService._();
  static final MonitoringService instance = MonitoringService._();

  final _hostRepo = HostRepository();
  final _registry = CollectorRegistry.instance;
  final collector = HostMetricCollector();
  final _retention = MetricRetention();

  Timer? _monitorTimer;
  Timer? _retentionTimer;
  bool _isRunning = false;

  /// Guards a slow cycle overlapping the next tick: with a hundred hosts a
  /// 60-second interval is easily shorter than one sweep.
  bool _cycleInProgress = false;

  bool get isRunning => _isRunning;

  Future<void> startMonitoring({
    Duration interval = const Duration(seconds: 60),
    int retentionDays = 7,
  }) async {
    if (_isRunning) return;
    _isRunning = true;
    _retention.days = retentionDays;

    _registry.registerAll(CollectorRegistry.defaultCollectors());

    _monitorTimer = Timer.periodic(interval, (_) => unawaited(_collectAllMetrics()));

    _retentionTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => unawaited(purgeOldMetrics()),
    );

    logInfo('Monitoring started (every ${interval.inSeconds}s, $retentionDays day retention)');

    unawaited(_collectAllMetrics());
    unawaited(purgeOldMetrics());
  }

  void stopMonitoring() {
    _isRunning = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _retentionTimer?.cancel();
    _retentionTimer = null;
    logInfo('Monitoring stopped');
  }

  void setRetentionDays(int days) => _retention.days = days;

  Future<void> _collectAllMetrics() async {
    if (_cycleInProgress) {
      logWarning('Skipping collection cycle — the previous one is still running');
      return;
    }
    _cycleInProgress = true;

    try {
      for (final host in await _hostRepo.getAll()) {
        if (!_isRunning) break;
        try {
          await collector.collect(host);
        } catch (e) {
          logWarning('Metric collection failed for ${host.name}: $e');
        }
      }
    } catch (e, stack) {
      logError('Collection cycle failed', e, stack);
    } finally {
      _cycleInProgress = false;
    }
  }

  Future<int> purgeOldMetrics() => _retention.purge();

  Future<void> cleanup() async {
    stopMonitoring();
    await ConnectionManager.instance.disconnectAll();
  }
}
