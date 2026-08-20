import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/group.dart';
import '../data/models/host.dart';
import '../data/repositories/host_repository.dart';
import 'repository_providers.dart';

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
