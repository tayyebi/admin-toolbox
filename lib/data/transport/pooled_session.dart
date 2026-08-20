import 'transport_session.dart';

/// A session in the pool, with the count of who is currently using it.
class PooledSession {
  PooledSession(this.session, {required this.onIdle});

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
