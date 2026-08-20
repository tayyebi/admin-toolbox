import 'package:dartssh2/dartssh2.dart';

/// The socket, the client and the SFTP channel that belong to one connection.
///
/// Grouped so teardown is one call that cannot forget a layer — closing the
/// client but leaking its socket was how a timed-out connect used to leave a
/// file descriptor behind.
class SshConnection {
  SshConnection({required this.socket, required this.client});

  final SSHSocket socket;
  final SSHClient client;

  SftpClient? _sftp;

  Future<SftpClient> sftp() async => _sftp ??= await client.sftp();

  Future<void> close() async {
    try {
      _sftp?.close();
    } catch (_) {
      // Already gone.
    }
    _sftp = null;

    try {
      client.close();
    } catch (_) {
      // Already gone.
    }

    try {
      await socket.close();
    } catch (_) {
      // Already gone.
    }
  }
}
