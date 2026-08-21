import 'dart:convert';
import 'dart:typed_data';

import 'package:admin_toolbox/data/transport/ssh/ssh_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SshFingerprint', () {
    test('renders a raw MD5 digest as colon-separated hex', () {
      // What dartssh2 2.13 and earlier hand the callback: 16 raw bytes, which
      // are not valid UTF-8 and used to throw straight through the handshake.
      final digest = Uint8List.fromList([
        0x00, 0xff, 0x1a, 0x2b, 0x3c, 0x4d, 0x5e, 0x6f, //
        0x80, 0x91, 0xa2, 0xb3, 0xc4, 0xd5, 0xe6, 0xf7,
      ]);

      expect(
        SshFingerprint.format(digest),
        'MD5:00:ff:1a:2b:3c:4d:5e:6f:80:91:a2:b3:c4:d5:e6:f7',
      );
    });

    test('passes through a fingerprint dartssh2 already formatted', () {
      const formatted = 'SHA256:47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU';

      expect(
        SshFingerprint.format(Uint8List.fromList(utf8.encode(formatted))),
        formatted,
      );
    });

    test('renders a raw SHA-256 digest the way OpenSSH does', () {
      final digest = Uint8List(32);

      expect(
        SshFingerprint.format(digest),
        'SHA256:${base64.encode(digest).replaceAll('=', '')}',
      );
    });

    test('does not mistake a UTF-8-decodable digest for a formatted string', () {
      // 'hostkeydigest!!!' is valid UTF-8 but carries no algorithm prefix, so
      // it has to be read as digest bytes rather than trusted as a label.
      final digest = Uint8List.fromList(utf8.encode('hostkeydigest!!!'));

      expect(SshFingerprint.format(digest), startsWith('MD5:'));
    });
  });
}
