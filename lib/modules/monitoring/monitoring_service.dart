import 'dart:async';
import '../../data/models/host.dart';
import '../../data/models/identity.dart';
import '../../data/models/metric.dart';
import '../../data/transport/transport.dart';
import '../../data/repositories/host_repository.dart';
import '../../data/repositories/identity_repository.dart';
import '../../data/repositories/metric_repository.dart';
import '../../core/utils/logger.dart';
import 'collectors/collectors.dart';

class MonitoringService {
  MonitoringService._();
  static final MonitoringService instance = MonitoringService._();

  final _hostRepo = HostRepository();
  final _identityRepo = IdentityRepository();
  final _metricRepo = MetricRepository();
  final _registry = CollectorRegistry.instance;

  final _sessions = <String, TransportSession>{};
  Timer? _monitorTimer;
  bool _isRunning = false;

  Future<void> startMonitoring({Duration interval = const Duration(seconds: 60)}) async {
    if (_isRunning) return;
    _isRunning = true;

    _registry.registerAll(CollectorRegistry.defaultCollectors());

    _monitorTimer = Timer.periodic(interval, (_) async {
      await _collectAllMetrics();
    });

    await _collectAllMetrics();
    logInfo('Monitoring service started');
  }

  void stopMonitoring() {
    _isRunning = false;
    _monitorTimer?.cancel();
  }

  Future<void> _collectAllMetrics() async {
    try {
      final hosts = await _hostRepo.getAll();
      for (final host in hosts) {
        await collectHostMetrics(host).catchError((e) {
          logWarning('Failed to collect metrics for ${host.name}: $e');
        });
      }
    } catch (e) {
      logError('Metric collection cycle failed', e);
    }
  }

  Future<List<Metric>> collectHostMetrics(Host host) async {
    final session = await _getSession(host);
    if (session == null) {
      await _hostRepo.updateStatus(host.id, 'offline');
      return [];
    }

    await _hostRepo.updateStatus(host.id, 'online');

    final allMetrics = <Metric>[];

    for (final collector in _registry.all) {
      try {
        final metrics = await collector.collect(session, host.id);
        allMetrics.addAll(metrics);
      } catch (e) {
        logWarning('Collector ${collector.id} failed for ${host.name}: $e');
      }
    }

    await _metricRepo.insertBatch(allMetrics);
    return allMetrics;
  }

  Future<TransportSession?> _getSession(Host host) async {
    if (_sessions.containsKey(host.id)) {
      final session = _sessions[host.id]!;
      if (await session.isConnected) return session;
      _sessions.remove(host.id);
    }

    Identity? identity;
    if (host.identityId != null) {
      identity = await _identityRepo.getById(host.identityId!);
    }

    if (identity == null) return null;

    final config = TransportConnectionConfig(
      host: host.hostname,
      port: host.port,
      username: identity.username,
      password: identity.password,
      privateKey: identity.privateKey,
      passphrase: identity.passphrase,
    );

    try {
      final factory = SshTransportFactory();
      final session = await factory.create(config);
      _sessions[host.id] = session;
      return session;
    } catch (e) {
      logError('Failed to connect to ${host.name}', e);
      return null;
    }
  }

  Future<List<Metric>> getLatestMetrics(String hostId) async {
    return _metricRepo.getLatestForHost(hostId);
  }

  Future<MetricSeries> getMetricSeries(String hostId, String collectorId) async {
    return _metricRepo.getSeries(hostId, collectorId);
  }

  Future<int> calculateHealthScore(String hostId) async {
    final metrics = await getLatestMetrics(hostId);
    if (metrics.isEmpty) return 0;

    var score = 100.0;
    final deductions = <String, double>{};

    for (final metric in metrics) {
      final value = metric.numericValue;
      if (value == null) continue;

      if (metric.collectorId == 'cpu_usage' && value > 90) {
        deductions['cpu'] = 15;
      } else if (metric.collectorId == 'cpu_usage' && value > 75) {
        deductions['cpu'] = 8;
      } else if (metric.collectorId == 'cpu_usage' && value > 60) {
        deductions['cpu'] = 3;
      }

      if (metric.collectorId == 'memory_usage_pct' && value > 95) {
        deductions['memory'] = 20;
      } else if (metric.collectorId == 'memory_usage_pct' && value > 85) {
        deductions['memory'] = 10;
      } else if (metric.collectorId == 'memory_usage_pct' && value > 75) {
        deductions['memory'] = 5;
      }

      if (metric.collectorId == 'disk_usage_pct' && value > 95) {
        deductions['disk'] = 15;
      } else if (metric.collectorId == 'disk_usage_pct' && value > 85) {
        deductions['disk'] = 8;
      }

      if (metric.collectorId == 'svc_failed' && value > 0) {
        deductions['services'] = value * 5;
      }

      if (metric.collectorId == 'proc_zombies' && value > 10) {
        deductions['zombies'] = 10;
      } else if (metric.collectorId == 'proc_zombies' && value > 0) {
        deductions['zombies'] = 3;
      }
    }

    for (final deduction in deductions.values) {
      score -= deduction;
    }

    return score.clamp(0, 100).round();
  }

  Future<void> cleanup() async {
    stopMonitoring();
    for (final session in _sessions.values) {
      await session.disconnect().catchError((_) {});
    }
    _sessions.clear();
  }
}
