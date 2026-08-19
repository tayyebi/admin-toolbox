import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

Uint8List sha256OfBytes(Uint8List input) => SHA256Digest().process(input);

String hexEncode(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
