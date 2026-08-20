import 'vault_status.dart';

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
