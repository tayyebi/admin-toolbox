import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/alert_repository.dart';
import '../data/repositories/audit_repository.dart';
import '../data/repositories/automation_repository.dart';
import '../data/repositories/command_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/host_repository.dart';
import '../data/repositories/identity_repository.dart';
import '../data/repositories/incident_repository.dart';
import '../data/repositories/known_host_repository.dart';
import '../data/repositories/log_repository.dart';
import '../data/repositories/metric_repository.dart';

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
final logRepositoryProvider = Provider<LogRepository>((ref) => LogRepository());
