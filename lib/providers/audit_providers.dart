import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/audit_entry.dart';
import '../data/repositories/audit_repository.dart';
import 'repository_providers.dart';


final auditLogProvider = FutureProvider<List<AuditEntry>>((ref) async {
  return ref.watch(auditRepositoryProvider).getAll();
});

final auditSearchProvider = FutureProvider.family<List<AuditEntry>, String>((ref, query) async {
  final repo = ref.watch(auditRepositoryProvider);
  return query.isEmpty ? repo.getAll() : repo.search(query);
});
