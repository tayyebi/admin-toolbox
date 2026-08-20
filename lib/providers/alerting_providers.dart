import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/alert.dart';
import '../data/models/incident.dart';
import 'repository_providers.dart';

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
