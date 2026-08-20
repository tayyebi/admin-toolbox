import 'package:dartssh2/dartssh2.dart';

/// Supplies the session's lazily-opened SFTP channel.
///
/// The SFTP operations are split across several collaborators but must share
/// one channel — opening a second per operation would cost a round trip each
/// time and leave channels behind.
typedef SftpProvider = Future<SftpClient> Function();
