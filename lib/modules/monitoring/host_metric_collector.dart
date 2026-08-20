import '../../core/utils/logger.dart';
import '../../data/models/host.dart';
import '../../data/models/metric.dart';
import '../../data/repositories/host_repository.dart';
import '../../data/repositories/metric_repository.dart';
import '../../data/transport/connection_manager.dart';
import '../../data/transport/transport.dart';
import '../alerting/alert_engine.dart';
import 'collectors/collectors.dart';

/// Takes one reading from one host, stores it, and evaluates alert rules.
class HostMetricCollector {
  HostMetricCollector({
    HostRepository? hosts,
    MetricRepository? metrics,
    ConnectionManager? connections,
    AlertEngine? alerts,
    CollectorRegistry? registry,
  })  : _hosts = hosts ?? HostRepository(),
        _metrics = metrics ?? MetricRepository(),
        _connections = connections ?? ConnectionManager.instance,
        _alerts = alerts ?? AlertEngine(),
        _registry = registry ?? CollectorRegistry.instance;

  final HostRepository _hosts;
  final MetricRepository _metrics;
  final ConnectionManager _connections;
  final AlertEngine _alerts;
  final CollectorRegistry _registry;

  Future<List<Metric>> collect(Host host) async {
    // Paused hosts are never dialled by the sweep — that is the point of
    // pausing. Manual actions (terminal, files, test connection) still work;
    // they go through ConnectionManager directly, not this loop.
    if (host.monitoringPaused) {
      await _hosts.updateStatus(host.id, 'paused');
      return const [];
    }

    // A host with no credential can never be reached; marking it "offline"
    // hides a configuration problem behind what looks like a network problem.
    if (host.identityId == null || host.identityId!.isEmpty) {
      await _hosts.updateStatus(host.id, 'unknown');
      return const [];
    }

    try {
      return await _connections.withSession(host, (session) => _read(session, host));
    } on MissingIdentityException {
      await _hosts.updateStatus(host.id, 'unknown');
      rethrow;
    } catch (e) {
      logWarning('Could not reach ${host.name}: $e');
      await _hosts.updateStatus(host.id, 'offline');
      return const [];
    }
  }

  Future<List<Metric>> _read(TransportSession session, Host host) async {
    await _hosts.updateStatus(host.id, 'online');

    final collected = <Metric>[];
    for (final collector in _registry.all) {
      try {
        collected.addAll(await collector.collect(session, host.id));
      } catch (e) {
        logWarning('Collector ${collector.id} failed on ${host.name}: $e');
      }
    }

    if (collected.isNotEmpty) {
      await _metrics.insertBatch(collected);
      await _alerts.evaluate(host: host, metrics: collected);
    }
    return collected;
  }
}
