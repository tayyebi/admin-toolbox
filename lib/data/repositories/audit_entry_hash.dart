import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/audit_entry.dart';

/// Hashes one record together with the hash of the record before it.
///
/// The fields are joined with a NUL, which cannot occur in any of them. A
/// printable separator such as a space would let text move across a field
/// boundary without changing the payload: action `a b` with entity `c` would
/// hash the same as action `a` with entity `b c`.
///
/// The separator used to be a literal NUL byte in the source, which made this
/// file binary to every tool that touched it and left the separator invisible
/// to anyone reading the line. The escape below is the same byte, so hashes
/// computed before and after this change agree and existing chains verify.
String auditEntryHash(AuditEntry entry, String? previousHash) {
  final payload = [
    previousHash ?? '',
    entry.id,
    entry.action,
    entry.entityType,
    entry.entityId ?? '',
    entry.hostId ?? '',
    entry.details ?? '',
    entry.userId ?? '',
    entry.timestamp.toIso8601String(),
  ].join('\u0000');

  return sha256.convert(utf8.encode(payload)).toString();
}
