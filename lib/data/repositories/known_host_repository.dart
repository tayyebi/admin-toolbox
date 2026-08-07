import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';

/// A server host key the user has accepted.
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
enum HostKeyVerdict {
  /// Never seen — the user must decide whether to trust it.
  unknown,

  /// Matches the pinned key.
  trusted,

  /// A *different* key than the one pinned. Either the server was rebuilt, or
  /// something is intercepting the connection. Connections are refused.
  mismatch,
}

class HostKeyCheck {
  const HostKeyCheck(this.verdict, {this.pinned});
  final HostKeyVerdict verdict;
  final KnownHost? pinned;
}

class KnownHostRepository {
  final _uuid = const Uuid();

  Future<KnownHost?> find(String hostname, int port) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'known_hosts',
      where: 'hostname = ? AND port = ?',
      whereArgs: [hostname, port],
      limit: 1,
    );
    return maps.isEmpty ? null : KnownHost.fromMap(maps.first);
  }

  Future<HostKeyCheck> verify(String hostname, int port, String fingerprint) async {
    final pinned = await find(hostname, port);
    if (pinned == null) return const HostKeyCheck(HostKeyVerdict.unknown);

    if (pinned.fingerprint == fingerprint) {
      await _touch(pinned.id);
      return HostKeyCheck(HostKeyVerdict.trusted, pinned: pinned);
    }
    return HostKeyCheck(HostKeyVerdict.mismatch, pinned: pinned);
  }

  /// Pins a key on first sight, or replaces one the user has explicitly chosen
  /// to re-trust after a mismatch.
  Future<void> trust({
    required String hostname,
    required int port,
    required String keyType,
    required String fingerprint,
  }) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final existing = await find(hostname, port);

    final record = KnownHost(
      id: existing?.id ?? _uuid.v4(),
      hostname: hostname,
      port: port,
      keyType: keyType,
      fingerprint: fingerprint,
      firstSeen: existing?.firstSeen ?? now,
      lastSeen: now,
    );

    await db.insert(
      'known_hosts',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<KnownHost>> getAll() async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query('known_hosts', orderBy: 'hostname ASC');
    return maps.map(KnownHost.fromMap).toList();
  }

  Future<void> forget(String hostname, int port) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'known_hosts',
      where: 'hostname = ? AND port = ?',
      whereArgs: [hostname, port],
    );
  }

  Future<void> _touch(String id) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'known_hosts',
      {'last_seen': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
