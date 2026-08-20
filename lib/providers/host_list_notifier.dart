import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/host.dart';
import '../data/repositories/host_repository.dart';
import 'repository_providers.dart';


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

  Future<void> toggleMonitoringPaused(String id) async {
    await _repo.toggleMonitoringPaused(id);
    await loadHosts();
  }
}

final hostListProvider = StateNotifierProvider<HostListNotifier, AsyncValue<List<Host>>>((ref) {
  return HostListNotifier(
    ref.watch(hostRepositoryProvider),
    ref.watch(auditRepositoryProvider),
  );
});
