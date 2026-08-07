import 'dart:async';

import '../../core/utils/logger.dart';
import '../models/host.dart';
import '../models/identity.dart';
import '../repositories/identity_repository.dart';
import 'ssh_client.dart';
import 'transport.dart';

/// The single owner of live SSH sessions.
///
/// Monitoring, the terminal, the file browser and the automation engine all
/// want a connection to the same host. Previously each kept its own map and
/// never evicted, so a long-running app accumulated sockets until the server
/// or the OS refused more. Sessions are pooled per host, reference-counted
/// while in use, and dropped once idle.
class ConnectionManager {
  ConnectionManager._();
  static final ConnectionManager instance = ConnectionManager._();

  final _sessions = <String, _PooledSession>{};
  final _connecting = <String, Future<TransportSession>>{};

  final _identities = IdentityRepository();

  /// Asked before trusting an unknown or changed host key. The UI installs
  /// this at startup; when it is null, unknown keys are refused.
  HostKeyPromptCallback? onHostKeyPrompt;

  /// How long an unused session is kept before being closed.
  Duration idleTimeout = const Duration(minutes: 5);

  /// Borrows a session, opening one if needed.
  ///
  /// Callers must [release] when finished, ideally via [withSession].
  Future<TransportSession> acquire(Host host, {Duration? connectTimeout}) async {
    final existing = _sessions[host.id];
    if (existing != null) {
      if (existing.session.isConnected) {
        existing.retain();
        return existing.session;
      }
      // Dead socket: drop it and reconnect below.
      await _dispose(host.id);
    }

    // Collapse concurrent requests for the same host into one handshake.
    final inFlight = _connecting[host.id];
    if (inFlight != null) {
      final session = await inFlight;
      _sessions[host.id]?.retain();
      return session;
    }

    final future = _open(host, connectTimeout: connectTimeout);
    _connecting[host.id] = future;

    try {
      final session = await future;
      final pooled = _PooledSession(session, onIdle: () => _scheduleEviction(host.id));
      _sessions[host.id] = pooled;
      pooled.retain();
      return session;
    } finally {
      _connecting.remove(host.id);
    }
  }

  void release(Host host) => _sessions[host.id]?.release();

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

  bool isConnected(String hostId) => _sessions[hostId]?.session.isConnected ?? false;

  Future<TransportSession> _open(Host host, {Duration? connectTimeout}) async {
    final identity = await _resolveIdentity(host);

    final config = TransportConnectionConfig(
      host: host.hostname,
      port: host.port,
      username: identity.username,
      password: identity.password,
      privateKey: identity.privateKey,
      passphrase: identity.passphrase,
      connectTimeout: connectTimeout ?? const Duration(seconds: 15),
    );

    final factory = SshTransportFactory(onHostKeyPrompt: onHostKeyPrompt);
    final session = await factory.create(config);

    await _identities.markUsed(identity.id);
    return session;
  }

  Future<Identity> _resolveIdentity(Host host) async {
    final identityId = host.identityId;
    if (identityId == null || identityId.isEmpty) {
      throw MissingIdentityException(host);
    }

    final identity = await _identities.getById(identityId);
    if (identity == null) {
      throw MissingIdentityException(host);
    }
    return identity;
  }

  void _scheduleEviction(String hostId) {
    Timer(idleTimeout, () async {
      final pooled = _sessions[hostId];
      if (pooled == null || pooled.inUse) return;
      logInfo('Closing idle SSH session for host $hostId');
      await _dispose(hostId);
    });
  }

  Future<void> _dispose(String hostId) async {
    final pooled = _sessions.remove(hostId);
    if (pooled == null) return;
    try {
      await pooled.session.disconnect();
    } catch (e) {
      logWarning('Error closing session for host $hostId: $e');
    }
  }

  Future<void> disconnect(String hostId) => _dispose(hostId);

  Future<void> disconnectAll() async {
    final ids = _sessions.keys.toList();
    for (final id in ids) {
      await _dispose(id);
    }
  }
}

/// Thrown when a host has no usable credential attached.
///
/// This was the app's most consequential silent failure: `_getSession`
/// returned null and every host simply showed as offline, with nothing
/// pointing at the actual cause.
class MissingIdentityException implements Exception {
  const MissingIdentityException(this.host);

  final Host host;

  @override
  String toString() =>
      'No credential is attached to ${host.name}. Open the host and choose an '
      'identity from the vault.';
}

class _PooledSession {
  _PooledSession(this.session, {required this.onIdle});

  final TransportSession session;
  final void Function() onIdle;

  int _borrowers = 0;

  bool get inUse => _borrowers > 0;

  void retain() => _borrowers++;

  void release() {
    if (_borrowers > 0) _borrowers--;
    if (_borrowers == 0) onIdle();
  }
}
