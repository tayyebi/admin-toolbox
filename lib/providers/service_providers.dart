import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/crypto/encryption.dart';
import '../core/crypto/vault_migration.dart';
import '../data/transport/connection_manager.dart';
import '../modules/monitoring/monitoring_service.dart';
import 'repository_providers.dart';

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
