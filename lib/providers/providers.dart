import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/crypto/encryption.dart';
import '../core/crypto/vault_migration.dart';
import '../data/models/alert.dart';
import '../data/models/audit_entry.dart';
import '../data/models/automation.dart';
import '../data/models/command.dart';
import '../data/models/group.dart';
import '../data/models/host.dart';
import '../data/models/identity.dart';
import '../data/models/incident.dart';
import '../data/models/metric.dart';
import '../data/repositories/alert_repository.dart';
import '../data/repositories/audit_repository.dart';
import '../data/repositories/automation_repository.dart';
import '../data/repositories/command_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/host_repository.dart';
import '../data/repositories/identity_repository.dart';
import '../data/repositories/incident_repository.dart';
import '../data/repositories/known_host_repository.dart';
import '../data/repositories/metric_repository.dart';
import '../data/transport/connection_manager.dart';
import '../modules/monitoring/monitoring_service.dart';

// --- repositories ----------------------------------------------------------

final hostRepositoryProvider = Provider<HostRepository>((ref) => HostRepository());
final groupRepositoryProvider = Provider<GroupRepository>((ref) => GroupRepository());
final identityRepositoryProvider = Provider<IdentityRepository>((ref) => IdentityRepository());
final knownHostRepositoryProvider = Provider<KnownHostRepository>((ref) => KnownHostRepository());
final metricRepositoryProvider = Provider<MetricRepository>((ref) => MetricRepository());
final alertRepositoryProvider = Provider<AlertRepository>((ref) => AlertRepository());
final alertRuleRepositoryProvider = Provider<AlertRuleRepository>((ref) => AlertRuleRepository());
final incidentRepositoryProvider = Provider<IncidentRepository>((ref) => IncidentRepository());
final automationRepositoryProvider =
    Provider<AutomationRepository>((ref) => AutomationRepository());
final commandRepositoryProvider = Provider<CommandRepository>((ref) => CommandRepository());
final auditRepositoryProvider = Provider<AuditRepository>((ref) => AuditRepository());

// --- services --------------------------------------------------------------

final encryptionServiceProvider = Provider<EncryptionService>((ref) => EncryptionService.instance);
final monitoringServiceProvider = Provider<MonitoringService>((ref) => MonitoringService.instance);
final connectionManagerProvider = Provider<ConnectionManager>((ref) => ConnectionManager.instance);

final vaultMigrationProvider = Provider<VaultMigrationService>((ref) {
  return VaultMigrationService(
    ref.watch(identityRepositoryProvider),
    ref.watch(encryptionServiceProvider),
  );
});

// --- hosts -----------------------------------------------------------------

final hostsProvider = FutureProvider<List<Host>>((ref) async {
  return ref.watch(hostRepositoryProvider).getAll();
});

final hostsFilteredProvider = FutureProvider.family<List<Host>, String?>((ref, groupId) async {
  final repo = ref.watch(hostRepositoryProvider);
  return groupId == null ? repo.getAll() : repo.getByGroup(groupId);
});

final hostDetailProvider = FutureProvider.family<Host?, String>((ref, id) async {
  return ref.watch(hostRepositoryProvider).getById(id);
});

final favoriteHostsProvider = FutureProvider<List<Host>>((ref) async {
  return ref.watch(hostRepositoryProvider).getFavorites();
});

final hostSearchProvider = FutureProvider.family<List<Host>, String>((ref, query) async {
  return ref.watch(hostRepositoryProvider).search(query);
});

final hostStatusCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.watch(hostRepositoryProvider).getStatusCounts();
});

// --- groups ----------------------------------------------------------------

final groupsProvider = FutureProvider<List<Group>>((ref) async {
  return ref.watch(groupRepositoryProvider).getAll();
});

final groupTreeProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(groupRepositoryProvider).getGroupTree();
});

// --- vault -----------------------------------------------------------------

/// Vault list data: names, key types and fingerprints, no secrets.
final identitiesProvider = FutureProvider<List<Identity>>((ref) async {
  return ref.watch(identityRepositoryProvider).getAllRedacted();
});

final identityDetailProvider = FutureProvider.family<Identity?, String>((ref, id) async {
  return ref.watch(identityRepositoryProvider).getByIdRedacted(id);
});

/// How many hosts reference each identity.
final identityUsageProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.watch(identityRepositoryProvider).getHostUsageCounts();
});

final knownHostsProvider = FutureProvider<List<KnownHost>>((ref) async {
  return ref.watch(knownHostRepositoryProvider).getAll();
});

// --- alerts & incidents ----------------------------------------------------

final alertsProvider = FutureProvider<List<Alert>>((ref) async {
  return ref.watch(alertRepositoryProvider).getAll(status: 'active');
});

final allAlertsProvider = FutureProvider<List<Alert>>((ref) async {
  return ref.watch(alertRepositoryProvider).getAll();
});

final alertRulesProvider = FutureProvider<List<AlertRule>>((ref) async {
  return ref.watch(alertRuleRepositoryProvider).getAll();
});

final activeAlertCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(alertRepositoryProvider).getActiveCount();
});

final incidentsProvider = FutureProvider<List<Incident>>((ref) async {
  return ref.watch(incidentRepositoryProvider).getAll();
});

final incidentDetailProvider = FutureProvider.family<Incident?, String>((ref, id) async {
  return ref.watch(incidentRepositoryProvider).getById(id);
});

final openIncidentsCountProvider = FutureProvider<int>((ref) async {
  final open = await ref.watch(incidentRepositoryProvider).getAll(status: 'open');
  return open.length;
});

// --- automation & commands -------------------------------------------------

final automationsProvider = FutureProvider<List<Automation>>((ref) async {
  return ref.watch(automationRepositoryProvider).getAll();
});

final automationDetailProvider = FutureProvider.family<Automation?, String>((ref, id) async {
  return ref.watch(automationRepositoryProvider).getById(id);
});

final commandsProvider = FutureProvider<List<Command>>((ref) async {
  return ref.watch(commandRepositoryProvider).getAll();
});

final commandDetailProvider = FutureProvider.family<Command?, String>((ref, id) async {
  return ref.watch(commandRepositoryProvider).getById(id);
});

final favoriteCommandsProvider = FutureProvider<List<Command>>((ref) async {
  return ref.watch(commandRepositoryProvider).getFavorites();
});

// --- audit -----------------------------------------------------------------

final auditLogProvider = FutureProvider<List<AuditEntry>>((ref) async {
  return ref.watch(auditRepositoryProvider).getAll();
});

final auditSearchProvider = FutureProvider.family<List<AuditEntry>, String>((ref, query) async {
  final repo = ref.watch(auditRepositoryProvider);
  return query.isEmpty ? repo.getAll() : repo.search(query);
});

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

// --- host list mutations ---------------------------------------------------

class HostListNotifier extends StateNotifier<AsyncValue<List<Host>>> {
  HostListNotifier(this._repo, this._audit) : super(const AsyncValue.loading()) {
    loadHosts();
  }

  final HostRepository _repo;
  final AuditRepository _audit;

  Future<void> loadHosts() async {
    state = await AsyncValue.guard(() => _repo.getAll());
  }

  Future<void> addHost(Host host) async {
    await _repo.insert(host);
    await _audit.log(
      action: 'create',
      entityType: 'host',
      entityId: host.id,
      hostId: host.id,
      details: '${host.name} (${host.endpoint})',
    );
    await loadHosts();
  }

  Future<void> removeHost(String id) async {
    await _repo.delete(id);
    await _audit.log(action: 'delete', entityType: 'host', entityId: id, hostId: id);
    await loadHosts();
  }

  Future<void> toggleFavorite(String id) async {
    await _repo.toggleFavorite(id);
    await loadHosts();
  }
}

final hostListProvider = StateNotifierProvider<HostListNotifier, AsyncValue<List<Host>>>((ref) {
  return HostListNotifier(
    ref.watch(hostRepositoryProvider),
    ref.watch(auditRepositoryProvider),
  );
});
