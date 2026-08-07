import 'dart:convert';

/// Serialisation helpers shared by the models.
///
/// The first schema stored collections as delimiter-joined strings —
/// `a=1,b=2` for maps, `a,b` for lists, `type|command` for automation steps.
/// Any value containing the delimiter was silently corrupted, which for a tool
/// that stores shell commands is a matter of when, not if. Everything is JSON
/// now; the decoders still accept the legacy shapes so existing databases keep
/// reading, and rows convert on their next write.

String encodeStringMap(Map<String, String>? value) {
  if (value == null || value.isEmpty) return '';
  return jsonEncode(value);
}

Map<String, String> decodeStringMap(String? raw) {
  if (raw == null || raw.isEmpty) return const {};

  if (_looksLikeJsonObject(raw)) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry('$k', '$v'));
      }
    } catch (_) {
      // Fall through to the legacy parser.
    }
  }

  final result = <String, String>{};
  for (final pair in raw.split(',')) {
    final index = pair.indexOf('=');
    if (index > 0) {
      result[pair.substring(0, index).trim()] = pair.substring(index + 1).trim();
    }
  }
  return result;
}

String encodeStringList(List<String>? value) {
  if (value == null || value.isEmpty) return '';
  return jsonEncode(value);
}

List<String> decodeStringList(String? raw) {
  if (raw == null || raw.isEmpty) return const [];

  if (_looksLikeJsonArray(raw)) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => '$e').where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {
      // Fall through to the legacy parser.
    }
  }

  return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

/// Encodes a list of objects already reduced to JSON-safe maps.
String encodeObjectList(List<Map<String, dynamic>> value) {
  if (value.isEmpty) return '';
  return jsonEncode(value);
}

List<Map<String, dynamic>> decodeObjectList(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
  } catch (_) {
    // Legacy rows were newline-joined JSON fragments that cannot be recovered
    // reliably; treat them as empty rather than guessing.
  }
  return const [];
}

DateTime? parseDateOrNull(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

bool _looksLikeJsonObject(String raw) => raw.trimLeft().startsWith('{');

bool _looksLikeJsonArray(String raw) => raw.trimLeft().startsWith('[');
