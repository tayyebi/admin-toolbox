import 'dart:typed_data';

import 'ssh_fingerprint_format.dart';
import 'ssh_fingerprint_formats.dart';

/// Picks the dialect that fits the bytes dartssh2 handed `onVerifyHostKey`.
///
/// What that argument holds depends on the resolved library version:
///
/// | dartssh2        | fingerprint argument                          |
/// | --------------- | --------------------------------------------- |
/// | 2.10.0 – 2.17.0 | raw 16-byte MD5 digest of the host key         |
/// | 2.18.0 – 3.x    | UTF-8 bytes of `SHA256:<base64, unpadded>`     |
///
/// Reading the older form as UTF-8 throws, and in 2.10.0 – 2.19.0 anything
/// thrown out of the callback is passed to `closeWithError(SSHError)`. That
/// cast fails, the TypeError is lost to the zone, and the handshake is then
/// neither completed nor failed — every connection dies on the caller's
/// timeout, pointing at the network instead of at this decode. 2.20.0 awaits
/// the callback instead, which is why the fault is version-specific.
///
/// Which of those versions is in the build is not settled here: `pointycastle`
/// and the Flutter SDK's pinned `meta` both narrow it (see `pubspec.yaml`). So
/// the format is read from the bytes, and every branch of that decision is a
/// [SshFingerprintFormat] rather than a condition inline.
abstract final class SshFingerprint {
  /// Most specific first. The last entry matches anything, so selection always
  /// succeeds — an unknown dialect must never be able to throw from here.
  static const dialects = <SshFingerprintFormat>[
    PreformattedFingerprint(),
    Md5DigestFingerprint(),
    Sha256DigestFingerprint(),
    OpaqueDigestFingerprint(),
  ];

  static SshFingerprintFormat dialectFor(Uint8List bytes) => dialects.firstWhere(
        (dialect) => dialect.matches(bytes),
        orElse: () => const OpaqueDigestFingerprint(),
      );

  static String format(Uint8List bytes) => dialectFor(bytes).render(bytes);
}
