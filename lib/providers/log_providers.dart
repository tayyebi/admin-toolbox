import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/log_entry.dart';
import '../data/repositories/log_repository.dart';
import 'repository_providers.dart';

final logsProvider = FutureProvider<List<LogEntry>>((ref) async {
  return ref.watch(logRepositoryProvider).getAll();
});

final logSearchProvider = FutureProvider.family<List<LogEntry>, String>((ref, query) async {
  final repo = ref.watch(logRepositoryProvider);
  return query.isEmpty ? repo.getAll() : repo.search(query);
});
