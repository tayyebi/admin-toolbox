import 'dart:async';

abstract class TransportSession {
  TransportType get type;

  Future<CommandResult> execute(String command, {Duration? timeout});
  Future<void> uploadFile(String localPath, String remotePath);
  Future<List<int>> downloadFile(String remotePath);
  Future<List<FileEntry>> listDirectory(String path);
  Future<void> createDirectory(String path);
  Future<void> deleteFile(String path);
  Future<void> renameFile(String oldPath, String newPath);
  Future<Stream<String>> createShell();
  Future<void> disconnect();
  Future<bool> get isConnected;
}

enum TransportType {
  ssh,
  sftp,
  ftp,
  ftps,
  https,
}

class CommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;

  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
  });

  bool get isSuccess => exitCode == 0;
}

class FileEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modifiedAt;
  final String permissions;

  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modifiedAt,
    required this.permissions,
  });
}

class TransportConnectionConfig {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? passphrase;
  final Duration connectTimeout;
  final Duration commandTimeout;

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
}

abstract class TransportFactory {
  TransportType get type;
  Future<TransportSession> create(TransportConnectionConfig config);
}
