import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/host.dart';
import '../data/models/group.dart';
import '../data/models/identity.dart';
import '../data/models/alert.dart';
import '../data/models/incident.dart';
import '../data/models/automation.dart';
import '../data/models/command.dart';
import '../data/models/audit_entry.dart';
import '../data/models/metric.dart';
import '../data/repositories/host_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/identity_repository.dart';
import '../data/repositories/metric_repository.dart';
import '../data/repositories/alert_repository.dart';
import '../data/repositories/incident_repository.dart';
import '../data/repositories/automation_repository.dart';
import '../data/repositories/command_repository.dart';
import '../data/repositories/audit_repository.dart';
import '../core/crypto/encryption.dart';
import '../modules/monitoring/monitoring_service.dart';

final hostRepositoryProvider = Provider<HostRepository>((ref) => HostRepository());
final groupRepositoryProvider = Provider<GroupRepository>((ref) => GroupRepository());
final identityRepositoryProvider = Provider<IdentityRepository>((ref) => IdentityRepository());
final metricRepositoryProvider = Provider<MetricRepository>((ref) => MetricRepository());
final alertRepositoryProvider = Provider<AlertRepository>((ref) => AlertRepository());
final alertRuleRepositoryProvider = Provider<AlertRuleRepository>((ref) => AlertRuleRepository());
final incidentRepositoryProvider = Provider<IncidentRepository>((ref) => IncidentRepository());
final automationRepositoryProvider = Provider<AutomationRepository>((ref) => AutomationRepository());
final commandRepositoryProvider = Provider<CommandRepository>((ref) => CommandRepository());
final auditRepositoryProvider = Provider<AuditRepository>((ref) => AuditRepository());
final encryptionServiceProvider = Provider<EncryptionService>((ref) => EncryptionService.instance);
final monitoringServiceProvider = Provider<MonitoringService>((ref) => MonitoringService.instance);

final hostsProvider = FutureProvider<List<Host>>((ref) async {
  final repo = ref.watch(hostRepositoryProvider);
  return repo.getAll();
});

final hostsFilteredProvider = FutureProvider.family<List<Host>, String?>((ref, groupId) async {
  final repo = ref.watch(hostRepositoryProvider);
  if (groupId == null) return repo.getAll();
  return repo.getByGroup(groupId);
});

final hostDetailProvider = FutureProvider.family<Host?, String>((ref, id) async {
  final repo = ref.watch(hostRepositoryProvider);
  return repo.getById(id);
});

final favoriteHostsProvider = FutureProvider<List<Host>>((ref) async {
  final repo = ref.watch(hostRepositoryProvider);
  return repo.getFavorites();
});

final hostSearchProvider = FutureProvider.family<List<Host>, String>((ref, query) async {
  final repo = ref.watch(hostRepositoryProvider);
  return repo.search(query);
});

final hostStatusCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(hostRepositoryProvider);
  return repo.getStatusCounts();
});

final groupsProvider = FutureProvider<List<Group>>((ref) async {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getAll();
});

final groupTreeProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getGroupTree();
});

final identitiesProvider = FutureProvider<List<Identity>>((ref) async {
  final repo = ref.watch(identityRepositoryProvider);
  return repo.getAll();
});

final identityDetailProvider = FutureProvider.family<Identity?, String>((ref, id) async {
  final repo = ref.watch(identityRepositoryProvider);
  return repo.getById(id);
});

final alertsProvider = FutureProvider<List<Alert>>((ref) async {
  final repo = ref.watch(alertRepositoryProvider);
  return repo.getAll(status: 'active');
});

final alertRulesProvider = FutureProvider<List<AlertRule>>((ref) async {
  final repo = ref.watch(alertRuleRepositoryProvider);
  return repo.getAll();
});

final activeAlertCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(alertRepositoryProvider);
  return repo.getActiveCount();
});

final incidentsProvider = FutureProvider<List<Incident>>((ref) async {
  final repo = ref.watch(incidentRepositoryProvider);
  return repo.getAll();
});

final openIncidentsCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(incidentRepositoryProvider);
  final open = await repo.getAll(status: 'open');
  return open.length;
});

final automationsProvider = FutureProvider<List<Automation>>((ref) async {
  final repo = ref.watch(automationRepositoryProvider);
  return repo.getAll();
});

final commandsProvider = FutureProvider<List<Command>>((ref) async {
  final repo = ref.watch(commandRepositoryProvider);
  return repo.getAll();
});

final favoriteCommandsProvider = FutureProvider<List<Command>>((ref) async {
  final repo = ref.watch(commandRepositoryProvider);
  return repo.getFavorites();
});

final auditLogProvider = FutureProvider<List<AuditEntry>>((ref) async {
  final repo = ref.watch(auditRepositoryProvider);
  return repo.getAll();
});

final hostMetricsProvider = FutureProvider.family<List<Metric>, String>((ref, hostId) async {
  final repo = ref.watch(metricRepositoryProvider);
  return repo.getLatestForHost(hostId);
});

final metricSeriesProvider = FutureProvider.family<MetricSeries, ({String hostId, String collectorId})>(
  (ref, params) async {
    final repo = ref.watch(metricRepositoryProvider);
    return repo.getSeries(params.hostId, params.collectorId);
  },
);

final healthScoreProvider = FutureProvider.family<int, String>((ref, hostId) async {
  final service = ref.watch(monitoringServiceProvider);
  return service.calculateHealthScore(hostId);
});

final masterPasswordSetProvider = FutureProvider<bool>((ref) async {
  final encryption = ref.watch(encryptionServiceProvider);
  return encryption.isMasterKeySet();
});

final isMonitoringProvider = StateProvider<bool>((ref) => false);

class HostListNotifier extends StateNotifier<AsyncValue<List<Host>>> {
  final HostRepository _repo;

  HostListNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadHosts();
  }

  Future<void> loadHosts() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getAll());
  }

  Future<void> addHost(Host host) async {
    await _repo.insert(host);
    await loadHosts();
  }

  Future<void> removeHost(String id) async {
    await _repo.delete(id);
    await loadHosts();
  }

  Future<void> toggleFavorite(String id) async {
    await _repo.toggleFavorite(id);
    await loadHosts();
  }
}

final hostListProvider = StateNotifierProvider<HostListNotifier, AsyncValue<List<Host>>>((ref) {
  final repo = ref.watch(hostRepositoryProvider);
  return HostListNotifier(repo);
});
