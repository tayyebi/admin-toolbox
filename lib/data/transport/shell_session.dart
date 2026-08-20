import 'dart:typed_data';

/// An interactive shell with a PTY attached.
abstract class ShellSession {
  /// Everything the remote side writes, stdout and stderr interleaved as a
  /// terminal would see them.
  Stream<Uint8List> get output;

  /// Sends keystrokes to the remote shell.
  void write(Uint8List data);

  /// Tells the remote PTY the window changed, so full-screen programs redraw
  /// at the right size.
  void resize(int columns, int rows, {int pixelWidth = 0, int pixelHeight = 0});

  /// Completes when the remote shell exits.
  Future<void> get done;

  Future<void> close();
}
