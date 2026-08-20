import '../crypto/encryption.dart';
import '../utils/logger.dart';
import 'biometric_gate.dart';
import 'unlock_result.dart';

/// Performs the side effects of opening or creating the vault.
///
/// Split from the controller because those are two different jobs: this one
/// touches the keystore and the crypto, the controller decides what the
/// result means for what the user sees.
class VaultUnlocker {
  const VaultUnlocker(this._encryption, this._biometrics);

  final EncryptionService _encryption;
  final BiometricGate _biometrics;

  Future<UnlockResult> create(String password) async {
    try {
      await _encryption.initialize(password);
      return UnlockResult.succeeded;
    } catch (e, stack) {
      logError('Vault initialisation failed', e, stack);
      return UnlockResult.failed;
    }
  }

  Future<UnlockResult> withPassword(String password) async {
    try {
      return await _encryption.unlock(password)
          ? UnlockResult.succeeded
          : UnlockResult.rejected;
    } catch (e, stack) {
      logError('Vault unlock failed', e, stack);
      return UnlockResult.failed;
    }
  }

  Future<UnlockResult> withBiometrics() async {
    try {
      if (!await _biometrics.authenticate()) return UnlockResult.rejected;
      return await _encryption.unlockWithBiometricKey()
          ? UnlockResult.succeeded
          : UnlockResult.unavailable;
    } catch (e, stack) {
      logError('Biometric unlock failed', e, stack);
      return UnlockResult.failed;
    }
  }
}
