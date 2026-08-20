import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../crypto/encryption.dart';
import '../settings/app_settings.dart';
import 'app_lock_controller.dart';

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
