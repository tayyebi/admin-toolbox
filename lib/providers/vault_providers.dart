import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/identity.dart';
import '../data/repositories/identity_repository.dart';
import '../data/repositories/known_host_repository.dart';
import 'repository_providers.dart';

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
