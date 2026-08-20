/// The vault's public surface.
///
/// Kept as a barrel so the rest of the app imports one path and stays out of
/// the envelope's internal shape.
library;

export 'aead.dart';
export 'biometric_wrap.dart';
export 'digest.dart';
export 'encryption_service.dart';
export 'kdf.dart';
export 'legacy_vault.dart';
export 'password_wrap.dart';
export 'secure_random.dart';
export 'vault_exceptions.dart';
export 'vault_keys.dart';
export 'vault_storage.dart';
