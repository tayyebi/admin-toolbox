import 'dart:convert';
import 'dart:typed_data';

import 'package:admin_toolbox/data/transport/ssh/ssh_fingerprint.dart';
import 'package:admin_toolbox/data/transport/ssh/ssh_fingerprint_formats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SshFingerprint dialects', () {
    test('reads the raw MD5 digest dartssh2 <= 2.17 passes', () {
      // 16 raw bytes, not valid UTF-8. Decoding these is what threw straight
      // through the handshake and left every connection to time out.
      final digest = Uint8List.fromList([
        0x00, 0xff, 0x1a, 0x2b, 0x3c, 0x4d, 0x5e, 0x6f, //
        0x80, 0x91, 0xa2, 0xb3, 0xc4, 0xd5, 0xe6, 0xf7,
      ]);

      expect(SshFingerprint.dialectFor(digest), isA<Md5DigestFingerprint>());
      expect(
        SshFingerprint.format(digest),
        'MD5:00:ff:1a:2b:3c:4d:5e:6f:80:91:a2:b3:c4:d5:e6:f7',
      );
    });

    test('passes through the string dartssh2 >= 2.18 passes', () {
      const formatted = 'SHA256:47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU';
      final bytes = Uint8List.fromList(utf8.encode(formatted));

      expect(SshFingerprint.dialectFor(bytes), isA<PreformattedFingerprint>());
      expect(SshFingerprint.format(bytes), formatted);
    });

    test('renders a bare SHA-256 digest the way OpenSSH would', () {
      final digest = Uint8List(32);

      expect(SshFingerprint.dialectFor(digest), isA<Sha256DigestFingerprint>());
      expect(
        SshFingerprint.format(digest),
        'SHA256:${base64.encode(digest).replaceAll('=', '')}',
      );
    });

    test('does not mistake a UTF-8-decodable digest for a formatted string', () {
      // Valid UTF-8, but no algorithm prefix, so it is digest bytes and not a
      // label a newer dartssh2 produced.
      final digest = Uint8List.fromList(utf8.encode('hostkeydigest!!!'));

      expect(SshFingerprint.dialectFor(digest), isA<Md5DigestFingerprint>());
    });

    test('falls back rather than failing on bytes no dialect claims', () {
      final odd = Uint8List.fromList([0xff, 0x00, 0xfe]);

      expect(SshFingerprint.dialectFor(odd), isA<OpaqueDigestFingerprint>());
      expect(SshFingerprint.format(odd), 'UNKNOWN:ff:00:fe');
    });

    test('every dialect renders whatever it claims, for any input', () {
      // The guarantee the guard rests on: a matched dialect never throws, so
      // an unrecognised dartssh2 cannot hang a handshake.
      for (var length = 0; length <= 64; length++) {
        final bytes = Uint8List.fromList(List.generate(length, (i) => (i * 7 + 200) % 256));
        expect(() => SshFingerprint.format(bytes), returnsNormally, reason: 'length $length');
      }
    });
  });
}
