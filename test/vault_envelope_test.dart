import 'dart:convert';
import 'dart:typed_data';

import 'package:admin_toolbox/core/crypto/encryption.dart';
import 'package:flutter_test/flutter_test.dart';

/// Envelope encryption, now that `VaultStorage` can be faked.
///
/// These paths previously had no coverage at all: `EncryptionService` reached
/// straight for `flutter_secure_storage`, which needs a platform channel, so
/// every wrap and unwrap was verified only by hand on a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sealed record format', () {
    final key = Uint8List.fromList(List.generate(32, (i) => i));

    test('round-trips through the DEK', () {
      final sealed = seal(key, utf8.encode('hunter2'));
      expect(utf8.decode(openSealed(key, sealed)), 'hunter2');
    });

    test('is nonce ‖ ciphertext ‖ tag, with a fresh nonce each time', () {
      final first = base64Decode(seal(key, utf8.encode('x')));
      final second = base64Decode(seal(key, utf8.encode('x')));

      expect(first.length, nonceLength + 1 + macBits ~/ 8);
      expect(first.sublist(0, nonceLength), isNot(second.sublist(0, nonceLength)));
    });

    test('rejects a tampered tag rather than returning garbage', () {
      final sealed = base64Decode(seal(key, utf8.encode('sudo rm -rf /')));
      sealed[sealed.length - 1] ^= 0xFF;

      expect(
        () => openSealed(key, base64Encode(sealed)),
        throwsA(isA<VaultDecryptException>()),
      );
    });

    test('rejects the wrong key', () {
      final sealed = seal(key, utf8.encode('secret'));
      final wrong = Uint8List.fromList(List.generate(32, (i) => i + 1));

      expect(() => openSealed(wrong, sealed), throwsA(isA<VaultDecryptException>()));
    });
  });

  group('EncryptionService', () {
    late InMemoryVaultStorage storage;
    late EncryptionService vault;

    setUp(() {
      storage = InMemoryVaultStorage();
      vault = EncryptionService(storage: storage);
    });

    test('starts locked and uninitialised', () async {
      expect(vault.isUnlocked, isFalse);
      expect(await vault.isInitialized(), isFalse);
      expect(() => vault.encryptValue('x'), throwsA(isA<VaultLockedException>()));
    });

    test('never stores the master password or the bare data key', () async {
      await vault.initialize('correct horse battery staple');

      final written = storage.snapshot.values.join();
      expect(written, isNot(contains('correct horse')));
      expect(written, isNot(contains(base64Encode(vault.requireDek()))));
      expect(storage.snapshot.keys, contains(VaultKeys.wrappedDek));
    });

    test('unlocks with the right password and refuses the wrong one', () async {
      await vault.initialize('right');
      final sealed = vault.encryptValue('id_rsa');
      vault.lock();

      expect(await vault.unlock('wrong'), isFalse);
      expect(vault.isUnlocked, isFalse);

      expect(await vault.unlock('right'), isTrue);
      expect(vault.decryptValue(sealed), 'id_rsa');
    });

    test('a password change rewraps rather than re-encrypting records', () async {
      await vault.initialize('old');
      final sealed = vault.encryptValue('token');
      final before = storage.snapshot[VaultKeys.wrappedDek];

      expect(await vault.changePassword('old', 'new'), isTrue);
      expect(storage.snapshot[VaultKeys.wrappedDek], isNot(before));

      vault.lock();
      expect(await vault.unlock('new'), isTrue);
      // The record was never touched, and still opens under the same DEK.
      expect(vault.decryptValue(sealed), 'token');
    });
  });
}
