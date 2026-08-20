import 'app_lock_state.dart';
import 'lock_attempt_policy.dart';
import 'unlock_result.dart';
import 'vault_status.dart';

/// What an [UnlockResult] does to the lock state.
///
/// Pure, so the back-off schedule and the wording the user sees can be tested
/// without a keystore, a biometric prompt or a real vault.
AppLockState afterUnlockAttempt(
  AppLockState current,
  UnlockResult result, {
  required bool countsAsFailure,
}) {
  switch (result) {
    case UnlockResult.succeeded:
      return afterUnlock(current);

    case UnlockResult.rejected:
      // Dismissing a biometric prompt is not a wrong password, and must not
      // spend an attempt.
      if (!countsAsFailure) return current.copyWith(busy: false);
      final attempts = current.failedAttempts + 1;
      return current.copyWith(
        busy: false,
        failedAttempts: attempts,
        lockoutUntil: LockAttemptPolicy.lockoutUntil(attempts),
        error: 'Incorrect master password.',
      );

    case UnlockResult.unavailable:
      return current.copyWith(
        busy: false,
        error: 'Biometric unlock is not set up. Use your master password.',
      );

    case UnlockResult.failed:
      return current.copyWith(busy: false, error: 'Could not unlock the vault.');
  }
}

AppLockState afterUnlock(AppLockState current) => current.copyWith(
      status: VaultStatus.unlocked,
      busy: false,
      failedAttempts: 0,
      clearLockout: true,
      clearError: true,
    );
