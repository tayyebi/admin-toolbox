import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../crypto/encryption.dart';
import '../settings/app_settings.dart';
import '../utils/logger.dart';

enum VaultStatus {
  /// Startup state, before secure storage has been consulted.
  unknown,

  /// No master password has ever been set on this device.
  needsSetup,
  locked,
  unlocked,
}

@immutable
class AppLockState {
  const AppLockState({
    this.status = VaultStatus.unknown,
    this.failedAttempts = 0,
    this.lockoutUntil,
    this.biometricAvailable = false,
    this.biometricConfigured = false,
    this.busy = false,
    this.error,
  });

  final VaultStatus status;
  final int failedAttempts;
  final DateTime? lockoutUntil;
  final bool biometricAvailable;
  final bool biometricConfigured;
  final bool busy;
  final String? error;

  bool get isUnlocked => status == VaultStatus.unlocked;
  bool get needsSetup => status == VaultStatus.needsSetup;

  bool get isLockedOut {
    final until = lockoutUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  Duration get lockoutRemaining {
    final until = lockoutUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Biometric unlock is offerable only when the hardware is present, the user
  /// has turned it on, and a key copy was actually stored.
  bool get canUseBiometrics => biometricAvailable && biometricConfigured;

  AppLockState copyWith({
    VaultStatus? status,
    int? failedAttempts,
    DateTime? lockoutUntil,
    bool clearLockout = false,
    bool? biometricAvailable,
    bool? biometricConfigured,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return AppLockState(
      status: status ?? this.status,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutUntil: clearLockout ? null : (lockoutUntil ?? this.lockoutUntil),
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      biometricConfigured: biometricConfigured ?? this.biometricConfigured,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns the locked/unlocked lifecycle of the vault.
///
/// The router watches this: until the status is [VaultStatus.unlocked] every
/// route redirects to setup or the lock screen, so no screen can render a
/// credential — or even a host list — before the DEK is in memory.
class AppLockController extends StateNotifier<AppLockState> {
  AppLockController(this._encryption, this._localAuth) : super(const AppLockState()) {
    unawaited(refresh());
  }

  final EncryptionService _encryption;
  final LocalAuthentication _localAuth;

  /// Wall-clock time the app was backgrounded, used to apply the auto-lock
  /// grace period on resume.
  DateTime? _backgroundedAt;

  /// Attempts allowed before back-off starts.
  static const int _freeAttempts = 3;

  Future<void> refresh() async {
    final initialized = await _encryption.isInitialized();
    final biometricConfigured = await _encryption.isBiometricUnlockConfigured();

    var biometricAvailable = false;
    try {
      biometricAvailable =
          await _localAuth.isDeviceSupported() && await _localAuth.canCheckBiometrics;
    } catch (e) {
      logWarning('Biometric capability check failed: $e');
    }

    state = state.copyWith(
      status: initialized
          ? (_encryption.isUnlocked ? VaultStatus.unlocked : VaultStatus.locked)
          : VaultStatus.needsSetup,
      biometricAvailable: biometricAvailable,
      biometricConfigured: biometricConfigured,
    );
  }

  Future<bool> setUp(String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _encryption.initialize(password);
      state = state.copyWith(status: VaultStatus.unlocked, busy: false, failedAttempts: 0);
      return true;
    } catch (e, stack) {
      logError('Vault initialisation failed', e, stack);
      state = state.copyWith(busy: false, error: 'Could not create the vault.');
      return false;
    }
  }

  Future<bool> unlock(String password) async {
    if (state.isLockedOut) return false;

    state = state.copyWith(busy: true, clearError: true);
    try {
      final ok = await _encryption.unlock(password);
      if (!ok) {
        _registerFailure();
        return false;
      }
      state = state.copyWith(
        status: VaultStatus.unlocked,
        busy: false,
        failedAttempts: 0,
        clearLockout: true,
        clearError: true,
      );
      return true;
    } catch (e, stack) {
      logError('Vault unlock failed', e, stack);
      state = state.copyWith(busy: false, error: 'Could not unlock the vault.');
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    if (!state.canUseBiometrics || state.isLockedOut) return false;

    state = state.copyWith(busy: true, clearError: true);
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock your credential vault',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!authenticated) {
        state = state.copyWith(busy: false);
        return false;
      }

      final released = await _encryption.unlockWithBiometricKey();
      if (!released) {
        state = state.copyWith(
          busy: false,
          error: 'Biometric unlock is not set up. Use your master password.',
        );
        return false;
      }

      state = state.copyWith(
        status: VaultStatus.unlocked,
        busy: false,
        failedAttempts: 0,
        clearLockout: true,
      );
      return true;
    } catch (e, stack) {
      logError('Biometric unlock failed', e, stack);
      state = state.copyWith(busy: false, error: 'Biometric unlock failed.');
      return false;
    }
  }

  Future<void> enableBiometricUnlock() async {
    await _encryption.enableBiometricUnlock();
    state = state.copyWith(biometricConfigured: true);
  }

  Future<void> disableBiometricUnlock() async {
    await _encryption.disableBiometricUnlock();
    state = state.copyWith(biometricConfigured: false);
  }

  void lock() {
    _encryption.lock();
    _backgroundedAt = null;
    state = state.copyWith(status: VaultStatus.locked, clearError: true);
  }

  /// Records when the app left the foreground so [applyAutoLock] can decide.
  void markBackgrounded() {
    if (state.isUnlocked) _backgroundedAt = DateTime.now();
  }

  /// Re-locks if the app stayed in the background longer than [delay].
  void applyAutoLock(Duration delay) {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null || !state.isUnlocked) return;

    if (delay <= Duration.zero || DateTime.now().difference(since) >= delay) {
      logInfo('Auto-locking vault after background timeout');
      lock();
    }
  }

  void _registerFailure() {
    final attempts = state.failedAttempts + 1;
    DateTime? lockoutUntil;

    if (attempts > _freeAttempts) {
      // 5s, 10s, 20s, 40s … capped at five minutes.
      final penalty = math.min(5 * (1 << (attempts - _freeAttempts - 1)), 300);
      lockoutUntil = DateTime.now().add(Duration(seconds: penalty));
    }

    state = state.copyWith(
      busy: false,
      failedAttempts: attempts,
      lockoutUntil: lockoutUntil,
      error: 'Incorrect master password.',
    );
  }
}

final localAuthProvider = Provider<LocalAuthentication>((ref) => LocalAuthentication());

final appLockProvider = StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController(EncryptionService.instance, ref.watch(localAuthProvider));
});

/// Convenience for widgets that only care whether the vault is open.
final vaultUnlockedProvider = Provider<bool>((ref) {
  return ref.watch(appLockProvider.select((s) => s.isUnlocked));
});

/// The auto-lock delay currently configured by the user.
final autoLockDelayProvider = Provider<Duration>((ref) {
  return ref.watch(settingsProvider.select((s) => s.autoLockDelay));
});
