import 'dart:convert';
import 'dart:typed_data';

import 'package:admin_toolbox/core/crypto/ssh_wire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

/// Covers the encoders and the primitives directly.
///
/// `EncryptionService` itself is not unit-tested here because it depends on
/// `flutter_secure_storage`, which needs a platform channel; its behaviour is
/// exercised by the lock-screen flow in the manual test plan. What *is*
/// testable without a device — the key derivation, the AEAD, and the wire
/// formats — is covered below.
void main() {
  group('SshWire', () {
    test('encodes a string with a big-endian length prefix', () {
      final encoded = SshWire.utf8String('ssh-rsa');
      expect(encoded.sublist(0, 4), [0, 0, 0, 7]);
      expect(utf8.decode(encoded.sublist(4)), 'ssh-rsa');
    });

    test('pads an mpint whose high bit is set', () {
      // 0x80 would read as negative, so a leading zero byte is required.
      final encoded = SshWire.mpint(BigInt.from(0x80));
      expect(encoded, [0, 0, 0, 2, 0, 0x80]);
    });

    test('does not pad an mpint whose high bit is clear', () {
      final encoded = SshWire.mpint(BigInt.from(0x7F));
      expect(encoded, [0, 0, 0, 1, 0x7F]);
    });

    test('encodes zero as an empty mpint', () {
      expect(SshWire.mpint(BigInt.zero), [0, 0, 0, 0]);
    });

    test('produces an unpadded SHA256 fingerprint', () {
      final blob = Uint8List.fromList(utf8.encode('test'));
      final fingerprint = SshWire.fingerprintOf(blob);

      expect(fingerprint, startsWith('SHA256:'));
      expect(fingerprint, isNot(contains('=')));
    });

    test('round-trips a public key line', () {
      final blob = SshWire.rsaPublicBlob(BigInt.from(65537), BigInt.from(3233));
      final line = SshWire.authorizedKeyLine('ssh-rsa', blob, 'user@host');

      expect(line, startsWith('ssh-rsa '));
      expect(line, endsWith(' user@host'));
      expect(SshWire.algorithmOfPublicKeyLine(line), 'ssh-rsa');
      expect(SshWire.commentOfPublicKeyLine(line), 'user@host');
      expect(SshWire.publicKeyBlobFromLine(line), blob);
      expect(SshWire.fingerprintOfPublicKeyLine(line), SshWire.fingerprintOf(blob));
    });

    test('rejects a malformed public key line', () {
      expect(SshWire.publicKeyBlobFromLine('not a key'), isNull);
      expect(SshWire.fingerprintOfPublicKeyLine(''), isNull);
      expect(SshWire.algorithmOfPublicKeyLine('garbage data here'), isNull);
    });
  });

  group('Der', () {
    test('encodes a short-form length', () {
      final encoded = Der.integer(BigInt.from(0x2A));
      expect(encoded, [0x02, 0x01, 0x2A]);
    });

    test('prefixes a zero byte on a high-bit integer', () {
      final encoded = Der.integer(BigInt.from(0x80));
      expect(encoded, [0x02, 0x02, 0x00, 0x80]);
    });

    test('encodes a long-form length for large payloads', () {
      final big = BigInt.parse('1' * 400);
      final encoded = Der.integer(big);
      // 0x82 signals a two-byte length follows.
      expect(encoded[0], 0x02);
      expect(encoded[1] & 0x80, 0x80);
    });

    test('wraps DER in PEM armour with 64-character lines', () {
      final der = Der.sequence([Der.integer(BigInt.from(1))]);
      final pem = Der.toPem(der, 'RSA PRIVATE KEY');

      expect(pem, startsWith('-----BEGIN RSA PRIVATE KEY-----\n'));
      expect(pem.trimRight(), endsWith('-----END RSA PRIVATE KEY-----'));

      final body = pem
          .split('\n')
          .where((line) => !line.startsWith('-----') && line.isNotEmpty);
      for (final line in body) {
        expect(line.length, lessThanOrEqualTo(64));
      }
    });

    test('sequence wraps its elements', () {
      final encoded = Der.sequence([
        Der.integer(BigInt.zero),
        Der.integer(BigInt.one),
      ]);
      expect(encoded[0], 0x30);
      expect(encoded[1], 6); // two 3-byte integers
    });
  });

  group('AES-256-GCM', () {
    Uint8List seal(Uint8List key, Uint8List nonce, List<int> plaintext) {
      final cipher = GCMBlockCipher(AESEngine())
        ..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
      return cipher.process(Uint8List.fromList(plaintext));
    }

    Uint8List open(Uint8List key, Uint8List nonce, Uint8List sealed) {
      final cipher = GCMBlockCipher(AESEngine())
        ..init(false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
      return cipher.process(sealed);
    }

    final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final nonce = Uint8List.fromList(List<int>.generate(12, (i) => i * 2));

    test('round-trips a value', () {
      final sealed = seal(key, nonce, utf8.encode('super secret passphrase'));
      expect(utf8.decode(open(key, nonce, sealed)), 'super secret passphrase');
    });

    test('appends a 16-byte authentication tag', () {
      const plaintext = 'abc';
      final sealed = seal(key, nonce, utf8.encode(plaintext));
      expect(sealed.length, plaintext.length + 16);
    });

    test('rejects a tampered ciphertext', () {
      // This is the property AES-CBC did not have: flipping a byte used to
      // decrypt to garbage that the app would happily use as a password.
      final sealed = seal(key, nonce, utf8.encode('secret'));
      sealed[0] ^= 0xFF;

      expect(
        () => open(key, nonce, sealed),
        throwsA(isA<InvalidCipherTextException>()),
      );
    });

    test('rejects the wrong key', () {
      final sealed = seal(key, nonce, utf8.encode('secret'));
      final wrongKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

      expect(
        () => open(wrongKey, nonce, sealed),
        throwsA(isA<InvalidCipherTextException>()),
      );
    });
  });

  group('PBKDF2-HMAC-SHA256', () {
    Uint8List derive(String password, Uint8List salt, int iterations) {
      final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
        ..init(Pbkdf2Parameters(salt, iterations, 32));
      return derivator.process(Uint8List.fromList(utf8.encode(password)));
    }

    test('matches RFC 6070-style vector for HMAC-SHA256', () {
      // password "password", salt "salt", 1 iteration, dkLen 32.
      final derived = derive('password', Uint8List.fromList(utf8.encode('salt')), 1);
      final hex = derived.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(
        hex,
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('is deterministic for the same inputs', () {
      final salt = Uint8List.fromList(List<int>.generate(16, (i) => i));
      expect(derive('hunter2', salt, 1000), derive('hunter2', salt, 1000));
    });

    test('a different salt gives a different key', () {
      final saltA = Uint8List.fromList(List<int>.generate(16, (i) => i));
      final saltB = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
      expect(derive('hunter2', saltA, 1000), isNot(derive('hunter2', saltB, 1000)));
    });

    test('produces a 32-byte key for AES-256', () {
      final salt = Uint8List.fromList(List<int>.generate(16, (i) => i));
      expect(derive('hunter2', salt, 100).length, 32);
    });
  });
}
