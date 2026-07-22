import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import '../../core/utils/logger.dart';
import 'transport.dart';

class SshTransportFactory extends TransportFactory {
  @override
  TransportType get type => TransportType.ssh;

  @override
  Future<TransportSession> create(TransportConnectionConfig config) async {
    final session = SshTransportSession();
    await session.connect(config);
    return session;
  }
}

class SshTransportSession implements TransportSession {
  SSHSocket? _socket;
  SSHClient? _client;
  bool _connected = false;

  @override
  TransportType get type => TransportType.ssh;

  @override
  Future<bool> get isConnected async => _connected;

  Future<void> connect(TransportConnectionConfig config) async {
    try {
      logInfo('Connecting to ${config.host}:${config.port}');

      _socket = await SSHSocket.connect(
        config.host,
        config.port,
        timeout: config.connectTimeout,
      );

      _client = SSHClient(
        _socket!,
        username: config.username,
        onPasswordRequest: config.password != null ? () => config.password! : null,
        identities: config.privateKey != null
            ? [SSHKeyPair.fromPem(config.privateKey!, config.passphrase)]
            : [],
      );

      _connected = true;
      logInfo('Connected to ${config.host}');
    } catch (e, stack) {
      logError('SSH connection failed: $config.host', e, stack);
      _connected = false;
      rethrow;
    }
  }

  @override
  Future<CommandResult> execute(String command, {Duration? timeout}) async {
    if (_client == null) {
      throw StateError('SSH session not connected');
    }

    final stopwatch = Stopwatch()..start();

    try {
      final result = await _client!.execute(
        command,
        timeout: timeout ?? const Duration(seconds: 30),
      );

      stopwatch.stop();

      return CommandResult(
        exitCode: result.exitCode ?? -1,
        stdout: utf8.decode(result.stdout),
        stderr: utf8.decode(result.stderr),
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<void> uploadFile(String localPath, String remotePath) async {
    throw UnimplementedError('SFTP upload not yet implemented');
  }

  @override
  Future<List<int>> downloadFile(String remotePath) async {
    throw UnimplementedError('SFTP download not yet implemented');
  }

  @override
  Future<List<FileEntry>> listDirectory(String path) async {
    final result = await execute('ls -la --time-style=long-iso "$path"');
    if (!result.isSuccess) return [];

    final entries = <FileEntry>[];
    final lines = result.stdout.split('\n').skip(1);
    for (final line in lines) {
      if (line.isEmpty || line.startsWith('total ')) continue;
      final parts = _parseLsLine(line);
      if (parts != null) {
        entries.add(FileEntry(
          name: parts['name']!,
          path: '$path/${parts['name']}',
          isDirectory: parts['isDir'] == true,
          size: int.tryParse(parts['size'] ?? '0') ?? 0,
          modifiedAt: DateTime.tryParse(parts['date'] ?? '') ?? DateTime.now(),
          permissions: parts['perms'] ?? '',
        ));
      }
    }
    return entries;
  }

  Map<String, dynamic>? _parseLsLine(String line) {
    if (line.isEmpty) return null;
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 9) return null;

    return {
      'perms': parts[0],
      'isDir': parts[0].startsWith('d'),
      'size': parts[4],
      'date': '${parts[5]} ${parts[6]}',
      'name': parts.sublist(7).join(' '),
    };
  }

  @override
  Future<void> createDirectory(String path) async {
    await execute('mkdir -p "$path"');
  }

  @override
  Future<void> deleteFile(String path) async {
    await execute('rm -rf "$path"');
  }

  @override
  Future<void> renameFile(String oldPath, String newPath) async {
    await execute('mv "$oldPath" "$newPath"');
  }

  @override
  Future<Stream<String>> createShell() async {
    if (_client == null) throw StateError('SSH session not connected');

    final session = await _client!.shell(
      pty: SSHPtyConfig(
        term: 'xterm-256color',
        width: 120,
        height: 40,
      ),
    );

    final controller = StreamController<String>();

    session.stdout.transform(utf8.decoder).listen(
      (data) => controller.add(data),
      onError: controller.addError,
      onDone: controller.close,
    );

    session.stderr.transform(utf8.decoder).listen(
      (data) => controller.add(data),
    );

    return controller.stream;
  }

  @override
  Future<void> disconnect() async {
    _client?.close();
    _socket?.close();
    _connected = false;
    logInfo('SSH session disconnected');
  }
}

class SftpTransportSession implements FileManagementTransport {
  SshTransportSession? _sshSession;
  Dio? _dio;

  @override
  TransportType get type => TransportType.sftp;

  Future<void> connectFromSsh(SshTransportSession sshSession) async {
    _sshSession = sshSession;
  }

  @override
  Future<void> uploadFile(String localPath, String remotePath) async {
    if (_sshSession == null) throw StateError('SFTP session not initialized');
    await _sshSession!.execute('cat > "$remotePath" < '); // Stub
  }

  @override
  Future<List<int>> downloadFile(String remotePath) async {
    if (_sshSession == null) throw StateError('SFTP session not initialized');
    final result = await _sshSession!.execute('cat "$remotePath"');
    return result.stdout.codeUnits;
  }

  @override
  Future<List<FileEntry>> listDirectory(String path) async {
    if (_sshSession == null) throw StateError('SFTP session not initialized');
    return _sshSession!.listDirectory(path);
  }

  @override
  Future<void> createDirectory(String path) async {
    await _sshSession?.createDirectory(path);
  }

  @override
  Future<void> deleteFile(String path) async {
    await _sshSession?.deleteFile(path);
  }

  @override
  Future<void> renameFile(String oldPath, String newPath) async {
    await _sshSession?.renameFile(oldPath, newPath);
  }
}

abstract class FileManagementTransport implements TransportSession {
  Future<void> uploadFile(String localPath, String remotePath);
  Future<List<int>> downloadFile(String remotePath);
  Future<List<FileEntry>> listDirectory(String path);
  Future<void> createDirectory(String path);
  Future<void> deleteFile(String path);
  Future<void> renameFile(String oldPath, String newPath);
}

class SshKeyPair {
  static SSHKeyPairIdentity fromPem(String pem, [String? passphrase]) {
    return SSHKeyPairIdentity(
      SSHKeyPair.fromPem(pem, passphrase: passphrase),
    );
  }
}
