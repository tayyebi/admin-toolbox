import 'dart:async';

import '../../core/utils/logger.dart';
import 'pooled_session.dart';
import 'transport_session.dart';

/// Live sessions, keyed by host, reference-counted while in use.
///
/// Before this existed each caller kept its own map and never evicted, so a
/// long-running app accumulated sockets until the server or the OS refused
/// more.
class ConnectionPool {
  /// How long an unused session is kept before being closed.
  Duration idleTimeout = const Duration(minutes: 5);

  final _sessions = <String, PooledSession>{};

  PooledSession? operator [](String hostId) => _sessions[hostId];

  bool isConnected(String hostId) => _sessions[hostId]?.session.isConnected ?? false;

  /// Adds a freshly opened session, already retained by its opener.
  PooledSession add(String hostId, TransportSession session) {
    final pooled = PooledSession(session, onIdle: () => _scheduleEviction(hostId));
    _sessions[hostId] = pooled;
    pooled.retain();
    return pooled;
  }

  void release(String hostId) => _sessions[hostId]?.release();

  void _scheduleEviction(String hostId) {
    Timer(idleTimeout, () async {
      final pooled = _sessions[hostId];
      if (pooled == null || pooled.inUse) return;
      logInfo('Closing idle SSH session for host $hostId');
      await dispose(hostId);
    });
  }

  Future<void> dispose(String hostId) async {
    final pooled = _sessions.remove(hostId);
    if (pooled == null) return;
    try {
      await pooled.session.disconnect();
    } catch (e) {
      logWarning('Error closing session for host $hostId: $e');
    }
  }

  Future<void> disposeAll() async {
    for (final id in _sessions.keys.toList()) {
      await dispose(id);
    }
  }
}
