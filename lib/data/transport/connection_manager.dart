import 'dart:async';

import '../../core/utils/logger.dart';
import '../models/host.dart';
import 'connection_pool.dart';
import 'host_status_reporter.dart';
import 'session_opener.dart';
import 'ssh/host_key_prompt.dart';
import 'transport_session.dart';

export 'connection_pool.dart';
export 'host_status_reporter.dart';
export 'missing_identity_exception.dart';
export 'session_opener.dart';

/// The single owner of live SSH sessions.
///
/// Monitoring, the terminal, the file browser and the automation engine all
/// want a connection to the same host. Sessions are pooled per host,
/// reference-counted while in use, and dropped once idle.
class ConnectionManager {
  ConnectionManager._();
  static final ConnectionManager instance = ConnectionManager._();

  final pool = ConnectionPool();
  final _opener = SessionOpener();
  final _status = HostStatusReporter();
  final _connecting = <String, Future<TransportSession>>{};

  /// Asked before trusting an unknown or changed host key. The UI installs
  /// this at startup; when it is null, unknown keys are refused.
  HostKeyPromptCallback? onHostKeyPrompt;

  Duration get idleTimeout => pool.idleTimeout;
  set idleTimeout(Duration value) => pool.idleTimeout = value;

  bool isConnected(String hostId) => pool.isConnected(hostId);

  /// Borrows a session, opening one if needed. Callers must [release] when
  /// finished, ideally via [withSession].
  Future<TransportSession> acquire(Host host, {Duration? connectTimeout}) async {
    final existing = pool[host.id];
    if (existing != null) {
      if (existing.session.isConnected) {
        existing.retain();
        logDebug('Reusing pooled SSH session for ${host.hostname}');
        return existing.session;
      }
      // Dead socket: drop it and reconnect below.
      logInfo('Pooled session for ${host.hostname} was dead; reconnecting');
      await pool.dispose(host.id);
    }

    // Collapse concurrent requests for the same host into one handshake.
    final inFlight = _connecting[host.id];
    if (inFlight != null) {
      logDebug('Connection to ${host.hostname} already in progress; waiting for it');
      final session = await inFlight;
      pool[host.id]?.retain();
      return session;
    }

    return _openAndPool(host, connectTimeout);
  }

  Future<TransportSession> _openAndPool(Host host, Duration? connectTimeout) async {
    final future = _opener.open(
      host,
      connectTimeout: connectTimeout,
      onHostKeyPrompt: onHostKeyPrompt,
    );
    _connecting[host.id] = future;

    try {
      final session = await _status.record(host.id, future);
      pool.add(host.id, session);
      return session;
    } finally {
      // The removed value is the same future already awaited above.
      _connecting.remove(host.id)?.ignore();
    }
  }

  void release(Host host) => pool.release(host.id);

  /// Borrow, use, release — including when [action] throws.
  Future<T> withSession<T>(
    Host host,
    Future<T> Function(TransportSession session) action, {
    Duration? connectTimeout,
  }) async {
    final session = await acquire(host, connectTimeout: connectTimeout);
    try {
      return await action(session);
    } finally {
      release(host);
    }
  }

  Future<void> disconnect(String hostId) => pool.dispose(hostId);

  Future<void> disconnectAll() => pool.disposeAll();
}
