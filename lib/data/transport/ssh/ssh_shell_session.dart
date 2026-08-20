import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../shell_session.dart';

class SshShellSession implements ShellSession {
  SshShellSession(this._session) {
    // stdout and stderr are merged: with a PTY attached the remote side
    // interleaves them anyway, and a terminal has only one screen.
    _subscriptions.add(_session.stdout.listen(_controller.add, onError: _controller.addError));
    _subscriptions.add(_session.stderr.listen(_controller.add));
    unawaited(_session.done.whenComplete(_controller.close));
  }

  final SSHSession _session;
  final _controller = StreamController<Uint8List>.broadcast();
  final _subscriptions = <StreamSubscription<Uint8List>>[];

  @override
  Stream<Uint8List> get output => _controller.stream;

  @override
  void write(Uint8List data) => _session.write(data);

  @override
  void resize(int columns, int rows, {int pixelWidth = 0, int pixelHeight = 0}) {
    _session.resizeTerminal(columns, rows, pixelWidth, pixelHeight);
  }

  @override
  Future<void> get done => _session.done;

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _session.close();
    if (!_controller.isClosed) await _controller.close();
  }
}
