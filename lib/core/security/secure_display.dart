import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Toggles Android's `FLAG_SECURE`.
///
/// With the flag set the OS refuses to screenshot the window and blanks the
/// task-switcher thumbnail — which matters here because those thumbnails would
/// otherwise capture a decrypted private key or an open terminal session.
class SecureDisplay {
  SecureDisplay._();

  static const _channel = MethodChannel('admin_toolbox/secure_display');

  static Future<void> setSecure(bool enabled) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'enabled': enabled});
    } on PlatformException catch (e) {
      logWarning('Could not set FLAG_SECURE: ${e.message}');
    } on MissingPluginException {
      // Host activity does not implement the channel (e.g. widget tests).
    }
  }
}
