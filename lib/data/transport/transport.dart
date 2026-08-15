import 'dart:async';
import 'dart:typed_data';

enum TransportType { ssh, sftp, ftp, ftps, https }

/// Raised when a server presents a host key we do not trust.
///
/// Carrying the fingerprints lets the UI show the user exactly what changed,
/// which is the difference between a decision and a shrug.
class HostKeyRejectedException implements Exception {
  const HostKeyRejectedException({
    required this.hostname,
    required this.port,
    required this.keyType,
    required this.presentedFingerprint,
    this.pinnedFingerprint,
  });

  final String hostname;
  final int port;
  final String keyType;
  final String presentedFingerprint;

  /// Null when the host was simply unknown rather than mismatched.
  final String? pinnedFingerprint;

  bool get isMismatch => pinnedFingerprint != null;

  @override
  String toString() {
    if (isMismatch) {
      return 'Host key for $hostname:$port has CHANGED. '
          'Expected $pinnedFingerprint but the server presented '
          '$presentedFingerprint.';
    }
    return 'Host key for $hostname:$port is not trusted yet '
        '($presentedFingerprint).';
  }
}

class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    this.timedOut = false,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final bool timedOut;

  bool get isSuccess => exitCode == 0 && !timedOut;

  /// stdout when the command worked, stderr when it did not — what a caller
  /// almost always wants to show.
  String get output => isSuccess ? stdout : (stderr.isEmpty ? stdout : stderr);
}

class FileEntry {
  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modifiedAt,
    required this.permissions,
    this.isSymlink = false,
    this.mode,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modifiedAt;

  /// Human-readable form, e.g. `drwxr-xr-x`.
  final String permissions;

  final bool isSymlink;

  /// Raw POSIX mode bits, for chmod round-trips.
  final int? mode;

  bool get isHidden => name.startsWith('.');
}

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

class TransportConnectionConfig {
  const TransportConnectionConfig({
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
    this.passphrase,
    this.connectTimeout = const Duration(seconds: 15),
    this.commandTimeout = const Duration(seconds: 30),
  });

  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? passphrase;
  final Duration connectTimeout;
  final Duration commandTimeout;

  /// Never includes credentials — this type ends up in log lines.
  @override
  String toString() => 'TransportConnectionConfig($username@$host:$port)';
}

abstract class TransportSession {
  TransportType get type;
  bool get isConnected;

  Future<CommandResult> execute(String command, {Duration? timeout});

  Future<List<FileEntry>> listDirectory(String path);
  Future<Uint8List> readFile(String path, {int? maxBytes});
  Future<void> writeFile(String path, Uint8List contents);
  Future<void> uploadFile(String localPath, String remotePath, {void Function(int, int)? onProgress});
  Future<void> downloadFile(String remotePath, String localPath, {void Function(int, int)? onProgress});
  Future<void> createDirectory(String path);
  Future<void> delete(String path, {bool recursive = false});
  Future<void> rename(String oldPath, String newPath);
  Future<void> chmod(String path, int mode);

  Future<ShellSession> openShell({int columns = 80, int rows = 24});

  Future<void> disconnect();
}

/// Emits a human-readable line as a connection attempt progresses. Used to
/// drive a live log panel (e.g. "Test connection") rather than relying on
/// the app log alone.
typedef ConnectionLogCallback = void Function(String message);

abstract class TransportFactory {
  TransportType get type;
  Future<TransportSession> create(TransportConnectionConfig config, {ConnectionLogCallback? onLog});
}
