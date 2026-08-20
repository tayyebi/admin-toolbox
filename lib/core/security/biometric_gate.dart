import 'package:local_auth/local_auth.dart';

import '../utils/logger.dart';

/// The OS-level "is this the right human" check.
///
/// A convenience gate, not a second secret: nothing cryptographically binds
/// the prompt's result to the key it releases, and `biometricOnly: false`
/// means the device PIN or pattern is an accepted answer too.
class BiometricGate {
  BiometricGate(this._localAuth);

  final LocalAuthentication _localAuth;

  Future<bool> isAvailable() async {
    try {
      return await _localAuth.isDeviceSupported() && await _localAuth.canCheckBiometrics;
    } catch (e) {
      logWarning('Biometric capability check failed: $e');
      return false;
    }
  }

  Future<bool> authenticate() => _localAuth.authenticate(
        localizedReason: 'Unlock your credential vault',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
}
