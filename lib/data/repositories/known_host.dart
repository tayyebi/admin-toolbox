import '../../core/utils/json_codec.dart';

class KnownHost {
  const KnownHost({
    required this.id,
    required this.hostname,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    required this.firstSeen,
    required this.lastSeen,
  });

  final String id;
  final String hostname;
  final int port;
  final String keyType;
  final String fingerprint;
  final DateTime firstSeen;
  final DateTime lastSeen;

  Map<String, dynamic> toMap() => {
        'id': id,
        'hostname': hostname,
        'port': port,
        'key_type': keyType,
        'fingerprint': fingerprint,
        'first_seen': firstSeen.toIso8601String(),
        'last_seen': lastSeen.toIso8601String(),
      };

  factory KnownHost.fromMap(Map<String, dynamic> map) => KnownHost(
        id: map['id'] as String,
        hostname: map['hostname'] as String,
        port: map['port'] as int,
        keyType: map['key_type'] as String,
        fingerprint: map['fingerprint'] as String,
        firstSeen: DateTime.parse(map['first_seen'] as String),
        lastSeen: DateTime.parse(map['last_seen'] as String),
      );
}

/// The outcome of checking a server's key against what we have pinned.
