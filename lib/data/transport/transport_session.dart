import 'dart:typed_data';

import 'command_result.dart';
import 'file_entry.dart';
import 'shell_session.dart';
import 'transport_connection_config.dart';
import 'transport_type.dart';

/// One live connection to a host.
///
/// Abstract so the protocol underneath can be replaced without the terminal,
/// the file browser, the collectors or the automation engine noticing.
abstract class TransportSession {
  TransportType get type;
  bool get isConnected;

  Future<CommandResult> execute(String command, {Duration? timeout});

  Future<List<FileEntry>> listDirectory(String path);
  Future<Uint8List> readFile(String path, {int? maxBytes});
  Future<void> writeFile(String path, Uint8List contents);
  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int, int)? onProgress,
  });
  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int, int)? onProgress,
  });
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

  Future<TransportSession> create(
    TransportConnectionConfig config, {
    ConnectionLogCallback? onLog,
  });
}
