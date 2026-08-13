import 'dart:async';

import '../../core/utils/logger.dart';
import '../../data/models/host.dart';
import '../../data/models/metric.dart';
import '../../data/repositories/host_repository.dart';
import '../../data/repositories/metric_repository.dart';
import '../../data/transport/connection_manager.dart';
import '../alerting/alert_engine.dart';
import 'collectors/collectors.dart';

class MonitoringService {
  MonitoringService._();
  static final MonitoringService instance = MonitoringService._();

  final _hostRepo = HostRepository();
  final _metricRepo = MetricRepository();
  final _registry = CollectorRegistry.instance;
  final _connections = ConnectionManager.instance;
  final _alerts = AlertEngine();

  Timer? _monitorTimer;
  Timer? _retentionTimer;
  bool _isRunning = false;

  /// Guards against a slow cycle overlapping the next tick — with a hundred
  /// hosts a 60-second interval can easily be shorter than one full sweep.
  bool _cycleInProgress = false;

  int _retentionDays = 7;

  bool get isRunning => _isRunning;

  Future<void> startMonitoring({
    Duration interval = const Duration(seconds: 60),
    int retentionDays = 7,
  }) async {
    if (_isRunning) return;
    _isRunning = true;
    _retentionDays = retentionDays;

    _registry.registerAll(CollectorRegistry.defaultCollectors());

    _monitorTimer = Timer.periodic(interval, (_) => unawaited(_collectAllMetrics()));

    // The metrics table previously grew without bound; a busy fleet fills the
    // device eventually.
    _retentionTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => unawaited(purgeOldMetrics()),
    );

    logInfo('Monitoring started (every ${interval.inSeconds}s, '
        'retaining $retentionDays days)');

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

  void setRetentionDays(int days) => _retentionDays = days;

  Future<void> _collectAllMetrics() async {
    if (_cycleInProgress) {
      logWarning('Skipping collection cycle — the previous one is still running');
      return;
    }
    _cycleInProgress = true;

    try {
      final hosts = await _hostRepo.getAll();
      for (final host in hosts) {
        if (!_isRunning) break;
        try {
          await collectHostMetrics(host);
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

  Future<List<Metric>> collectHostMetrics(Host host) async {
    // Paused hosts are never dialled by the sweep — that is the point of
    // pausing. Manual actions (terminal, files, test connection) still work;
    // they go through ConnectionManager directly, not this loop.
    if (host.monitoringPaused) {
      await _hostRepo.updateStatus(host.id, 'paused');
      return const [];
    }

    // A host with no credential can never be reached; marking it "offline"
    // hides a configuration problem behind what looks like a network problem.
    if (host.identityId == null || host.identityId!.isEmpty) {
      await _hostRepo.updateStatus(host.id, 'unknown');
      return const [];
    }

    try {
      return await _connections.withSession(host, (session) async {
        await _hostRepo.updateStatus(host.id, 'online');

        final collected = <Metric>[];
        for (final collector in _registry.all) {
          try {
            collected.addAll(await collector.collect(session, host.id));
          } catch (e) {
            logWarning('Collector ${collector.id} failed on ${host.name}: $e');
          }
        }

        if (collected.isNotEmpty) {
          await _metricRepo.insertBatch(collected);
          await _alerts.evaluate(host: host, metrics: collected);
        }

        return collected;
      });
    } on MissingIdentityException {
      await _hostRepo.updateStatus(host.id, 'unknown');
      rethrow;
    } catch (e) {
      logWarning('Could not reach ${host.name}: $e');
      await _hostRepo.updateStatus(host.id, 'offline');
      return const [];
    }
  }

  Future<int> purgeOldMetrics() async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: _retentionDays));
      final deleted = await _metricRepo.deleteOlderThan(cutoff);
      if (deleted > 0) logInfo('Purged $deleted metric rows older than $_retentionDays days');
      return deleted;
    } catch (e) {
      logWarning('Metric purge failed: $e');
      return 0;
    }
  }

  Future<List<Metric>> getLatestMetrics(String hostId) => _metricRepo.getLatestForHost(hostId);

  Future<MetricSeries> getMetricSeries(String hostId, String collectorId) =>
      _metricRepo.getSeries(hostId, collectorId);

  /// A 0-100 summary of a host's current state.
  ///
  /// Deductions are keyed by subsystem so a single overloaded subsystem is
  /// counted once, however many metrics report it.
  Future<int> calculateHealthScore(String hostId) async {
    final metrics = await getLatestMetrics(hostId);
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

  /// Returns the penalty for the highest threshold [value] exceeds.
  static double _tiered(double value, Map<int, double> thresholds) {
    final ordered = thresholds.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final threshold in ordered) {
      if (value > threshold) return thresholds[threshold]!;
    }
    return 0;
  }

  Future<void> cleanup() async {
    stopMonitoring();
    await _connections.disconnectAll();
  }
}
