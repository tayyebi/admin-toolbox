import '../../data/models/identity.dart';
import '../../data/repositories/identity_repository.dart';
import '../utils/logger.dart';
import 'encryption.dart';

/// Re-seals v1 records under the current AES-GCM scheme.
///
/// Runs once, immediately after a successful unlock — the only moment both the
/// legacy key and the new DEK are available. Records that cannot be recovered
/// are left in place with their v1 marker intact rather than being destroyed;
/// the user re-enters those credentials, which is recoverable, whereas
/// overwriting them is not.
class VaultMigrationService {
  VaultMigrationService(this._identities, this._encryption);

  final IdentityRepository _identities;
  final EncryptionService _encryption;

  Future<VaultMigrationResult> migrate() async {
    if (!_encryption.isUnlocked) {
      return const VaultMigrationResult(migrated: 0, failed: 0);
    }

    final pending = await _identities.getPendingMigration();
    if (pending.isEmpty) {
      await _encryption.legacy.clear();
      return const VaultMigrationResult(migrated: 0, failed: 0);
    }

    logInfo('Re-encrypting ${pending.length} vault record(s) to AES-GCM');

    var migrated = 0;
    var failed = 0;

    for (final identity in pending) {
      try {
        final recovered = identity.copyWith(
          password: await _recover(identity.password),
          privateKey: await _recover(identity.privateKey),
          passphrase: await _recover(identity.passphrase),
        );
        await _identities.rewriteMigrated(recovered);
        migrated++;
      } catch (e) {
        // Deliberately does not log the identity's contents.
        logWarning('Could not migrate identity ${identity.id}: $e');
        failed++;
      }
    }

    if (failed == 0) {
      await _encryption.legacy.clear();
    }

    logInfo('Vault migration complete: $migrated migrated, $failed failed');
    return VaultMigrationResult(migrated: migrated, failed: failed);
  }

  Future<String?> _recover(String? sealed) async {
    if (sealed == null || sealed.isEmpty) return null;
    final plaintext = await _encryption.legacy.decryptValue(sealed);
    if (plaintext == null) {
      throw const VaultDecryptException('legacy record could not be recovered');
    }
    return plaintext;
  }
}

class VaultMigrationResult {
  const VaultMigrationResult({required this.migrated, required this.failed});

  final int migrated;
  final int failed;

  bool get hadWork => migrated > 0 || failed > 0;
  bool get hasFailures => failed > 0;
}
