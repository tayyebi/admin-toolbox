import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/automation.dart';
import '../data/models/command.dart';
import 'repository_providers.dart';

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
