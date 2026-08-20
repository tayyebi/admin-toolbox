import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../crypto/encryption.dart';
import '../utils/logger.dart';
import 'app_lock_state.dart';
import 'auto_lock_timer.dart';
import 'biometric_gate.dart';
import 'lock_transitions.dart';
import 'unlock_result.dart';
import 'vault_status.dart';
import 'vault_unlocker.dart';

export 'app_lock_providers.dart';
export 'app_lock_state.dart';
export 'vault_status.dart';

/// Owns whether the vault is open. Side effects are [VaultUnlocker]'s and the
/// state machine `lock_transitions.dart`'s; this wires them together.
class AppLockController extends StateNotifier<AppLockState> {
  AppLockController(this._encryption, LocalAuthentication localAuth)
      : _biometrics = BiometricGate(localAuth),
        _unlocker = VaultUnlocker(_encryption, BiometricGate(localAuth)),
        super(const AppLockState()) {
    unawaited(refresh());
  }

  final EncryptionService _encryption;
  final BiometricGate _biometrics;
  final VaultUnlocker _unlocker;
  final _background = AutoLockTimer();

  Future<void> refresh() async {
    final initialized = await _encryption.isInitialized();

    state = state.copyWith(
      status: initialized
          ? (_encryption.isUnlocked ? VaultStatus.unlocked : VaultStatus.locked)
          : VaultStatus.needsSetup,
      biometricAvailable: await _biometrics.isAvailable(),
      biometricConfigured: await _encryption.biometric.isConfigured(),
    );
  }

  Future<bool> setUp(String password) async {
    _begin();
    final result = await _unlocker.create(password);
    if (result != UnlockResult.succeeded) {
      state = state.copyWith(busy: false, error: 'Could not create the vault.');
      return false;
    }
    state = afterUnlock(state);
    return true;
  }

  Future<bool> unlock(String password) async {
    if (state.isLockedOut) return false;
    _begin();
    return _apply(await _unlocker.withPassword(password), countsAsFailure: true);
  }

  Future<bool> unlockWithBiometrics() async {
    if (!state.canUseBiometrics || state.isLockedOut) return false;
    _begin();
    return _apply(await _unlocker.withBiometrics(), countsAsFailure: false);
  }

  Future<void> setBiometricUnlock(bool enabled) async {
    enabled
        ? await _encryption.biometric.enable(_encryption.requireDek())
        : await _encryption.biometric.disable();
    state = state.copyWith(biometricConfigured: enabled);
  }

  void lock() {
    _encryption.lock();
    _background.reset();
    state = state.copyWith(status: VaultStatus.locked, clearError: true);
  }

  /// Records when the app left the foreground, for [applyAutoLock].
  void markBackgrounded() {
    if (state.isUnlocked) _background.markBackgrounded();
  }

  /// Re-locks if backgrounded longer than [delay].
  void applyAutoLock(Duration delay) {
    if (!_background.expired(delay) || !state.isUnlocked) return;
    logInfo('Auto-locking vault after background timeout');
    lock();
  }
  void _begin() => state = state.copyWith(busy: true, clearError: true);

  bool _apply(UnlockResult result, {required bool countsAsFailure}) {
    state = afterUnlockAttempt(state, result, countsAsFailure: countsAsFailure);
    return state.isUnlocked;
  }
}
