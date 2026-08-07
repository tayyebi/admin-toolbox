import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import '../../core/crypto/ssh_key_service.dart';
import '../../core/utils/logger.dart';
import '../repositories/known_host_repository.dart';
import 'transport.dart';

/// Passed to the UI when a host key needs a human decision.
class HostKeyPrompt {
  const HostKeyPrompt({
    required this.hostname,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    this.pinnedFingerprint,
  });

  final String hostname;
  final int port;
  final String keyType;
  final String fingerprint;

  /// Set when a *different* key was previously pinned — the dangerous case.
  final String? pinnedFingerprint;

  bool get isMismatch => pinnedFingerprint != null;
}

/// Returns true to accept and pin the key.
typedef HostKeyPromptCallback = Future<bool> Function(HostKeyPrompt prompt);

class SshTransportFactory implements TransportFactory {
  SshTransportFactory({this.onHostKeyPrompt, KnownHostRepository? knownHosts})
      : _knownHosts = knownHosts ?? KnownHostRepository();

  final HostKeyPromptCallback? onHostKeyPrompt;
  final KnownHostRepository _knownHosts;

  @override
  TransportType get type => TransportType.ssh;

  @override
  Future<TransportSession> create(TransportConnectionConfig config) async {
    final session = SshTransportSession(
      knownHosts: _knownHosts,
      onHostKeyPrompt: onHostKeyPrompt,
    );
    await session.connect(config);
    return session;
  }
}

class SshTransportSession implements TransportSession {
  SshTransportSession({KnownHostRepository? knownHosts, this.onHostKeyPrompt})
      : _knownHosts = knownHosts ?? KnownHostRepository();

  final KnownHostRepository _knownHosts;
  final HostKeyPromptCallback? onHostKeyPrompt;

  SSHSocket? _socket;
  SSHClient? _client;
  SftpClient? _sftp;
  bool _connected = false;

  /// Captured inside the host-key callback so [connect] can throw something
  /// specific — dartssh2 surfaces a rejected key as a generic handshake error.
  HostKeyRejectedException? _hostKeyRejection;

  @override
  TransportType get type => TransportType.ssh;

  @override
  bool get isConnected => _connected && _client != null;

  Future<void> connect(TransportConnectionConfig config) async {
    logInfo('Connecting to ${config.username}@${config.host}:${config.port}');
    _hostKeyRejection = null;

    try {
      _socket = await SSHSocket.connect(
        config.host,
        config.port,
        timeout: config.connectTimeout,
      );

      final identities = _identitiesFor(config);

      _client = SSHClient(
        _socket!,
        username: config.username,
        identities: identities,
        onPasswordRequest:
            config.password != null && config.password!.isNotEmpty ? () => config.password! : null,
        onVerifyHostKey: (keyType, fingerprint) =>
            _verifyHostKey(config, keyType, fingerprint),
        handshakeTimeout: config.connectTimeout,
        authTimeout: config.connectTimeout,
      );

      await _client!.authenticated;
      _connected = true;
      logInfo('Connected to ${config.host}:${config.port}');
    } catch (e, stack) {
      _connected = false;
      await _closeQuietly();

      // A rejected host key is a security decision, not a network fault, and
      // must not be reported as "connection failed".
      final rejection = _hostKeyRejection;
      if (rejection != null) {
        logWarning('Refused host key for ${config.host}:${config.port}');
        throw rejection;
      }

      logError('SSH connection to ${config.host}:${config.port} failed', e, stack);
      rethrow;
    }
  }

  List<SSHKeyPair> _identitiesFor(TransportConnectionConfig config) {
    final pem = config.privateKey;
    if (pem == null || pem.isEmpty) return const [];
    return SshKeyService.instance.parse(pem, passphrase: config.passphrase);
  }

  /// Trust on first use, with a hard stop on change.
  ///
  /// dartssh2 hands us the OpenSSH-style `SHA256:…` fingerprint already
  /// formatted, so what is compared and what the user is shown are the same
  /// string they would get from `ssh-keygen -lf`.
  Future<bool> _verifyHostKey(
    TransportConnectionConfig config,
    String keyType,
    Uint8List fingerprintBytes,
  ) async {
    final fingerprint = utf8.decode(fingerprintBytes);
    final check = await _knownHosts.verify(config.host, config.port, fingerprint);

    switch (check.verdict) {
      case HostKeyVerdict.trusted:
        return true;

      case HostKeyVerdict.unknown:
        final prompt = onHostKeyPrompt;
        if (prompt == null) {
          // No one to ask — refuse rather than trusting silently.
          _hostKeyRejection = HostKeyRejectedException(
            hostname: config.host,
            port: config.port,
            keyType: keyType,
            presentedFingerprint: fingerprint,
          );
          return false;
        }

        final accepted = await prompt(
          HostKeyPrompt(
            hostname: config.host,
            port: config.port,
            keyType: keyType,
            fingerprint: fingerprint,
          ),
        );
        if (accepted) {
          await _knownHosts.trust(
            hostname: config.host,
            port: config.port,
            keyType: keyType,
            fingerprint: fingerprint,
          );
          return true;
        }
        _hostKeyRejection = HostKeyRejectedException(
          hostname: config.host,
          port: config.port,
          keyType: keyType,
          presentedFingerprint: fingerprint,
        );
        return false;

      case HostKeyVerdict.mismatch:
        // The pinned key changed. This is either a rebuilt server or an
        // interception; it is never accepted without an explicit override.
        final rejection = HostKeyRejectedException(
          hostname: config.host,
          port: config.port,
          keyType: keyType,
          presentedFingerprint: fingerprint,
          pinnedFingerprint: check.pinned?.fingerprint,
        );

        final prompt = onHostKeyPrompt;
        if (prompt == null) {
          _hostKeyRejection = rejection;
          return false;
        }

        final accepted = await prompt(
          HostKeyPrompt(
            hostname: config.host,
            port: config.port,
            keyType: keyType,
            fingerprint: fingerprint,
            pinnedFingerprint: check.pinned?.fingerprint,
          ),
        );
        if (accepted) {
          await _knownHosts.trust(
            hostname: config.host,
            port: config.port,
            keyType: keyType,
            fingerprint: fingerprint,
          );
          return true;
        }
        _hostKeyRejection = rejection;
        return false;
    }
  }

  @override
  Future<CommandResult> execute(String command, {Duration? timeout}) async {
    final client = _client;
    if (client == null || !_connected) {
      throw StateError('SSH session is not connected');
    }

    final limit = timeout ?? const Duration(seconds: 30);
    final stopwatch = Stopwatch()..start();

    try {
      final result = await _runToCompletion(client, command).timeout(limit);
      stopwatch.stop();
      return CommandResult(
        exitCode: result.exitCode,
        stdout: result.stdout,
        stderr: result.stderr,
        duration: stopwatch.elapsed,
      );
    } on TimeoutException {
      stopwatch.stop();
      // A hung command previously blocked the collector loop forever, because
      // the timeout parameter was accepted and never applied.
      logWarning('Command timed out after ${limit.inSeconds}s: $command');
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Command timed out after ${limit.inSeconds}s',
        duration: stopwatch.elapsed,
        timedOut: true,
      );
    } catch (e) {
      stopwatch.stop();
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: '$e',
        duration: stopwatch.elapsed,
      );
    }
  }

  Future<({int exitCode, String stdout, String stderr})> _runToCompletion(
    SSHClient client,
    String command,
  ) async {
    final session = await client.execute(command);

    final stdout = <int>[];
    final stderr = <int>[];

    await Future.wait([
      session.stdout.forEach(stdout.addAll),
      session.stderr.forEach(stderr.addAll),
      session.done,
    ]);

    return (
      exitCode: session.exitCode ?? -1,
      stdout: _decode(stdout),
      stderr: _decode(stderr),
    );
  }

  /// Remote output is not guaranteed to be valid UTF-8 — a truncated multibyte
  /// sequence or binary output must not blow up a metric collector.
  static String _decode(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);

  Future<SftpClient> _sftpClient() async {
    final client = _client;
    if (client == null || !_connected) {
      throw StateError('SSH session is not connected');
    }
    return _sftp ??= await client.sftp();
  }

  @override
  Future<List<FileEntry>> listDirectory(String path) async {
    final sftp = await _sftpClient();
    final names = await sftp.listdir(path);

    final entries = <FileEntry>[];
    for (final name in names) {
      if (name.filename == '.') continue;

      final attrs = name.attr;
      entries.add(
        FileEntry(
          name: name.filename,
          path: name.filename == '..'
              ? p.dirname(path)
              : p.join(path, name.filename),
          isDirectory: attrs.isDirectory,
          isSymlink: attrs.isSymbolicLink,
          size: attrs.size ?? 0,
          modifiedAt: attrs.modifyTime != null
              ? DateTime.fromMillisecondsSinceEpoch(attrs.modifyTime! * 1000)
              : DateTime.fromMillisecondsSinceEpoch(0),
          permissions: _permissionString(attrs),
          mode: attrs.mode?.value,
        ),
      );
    }

    // Directories first, then case-insensitive by name — `..` always leads.
    entries.sort((a, b) {
      if (a.name == '..') return -1;
      if (b.name == '..') return 1;
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return entries;
  }

  static String _permissionString(SftpFileAttrs attrs) {
    final mode = attrs.mode;
    if (mode == null) return '';

    final type = attrs.isDirectory
        ? 'd'
        : attrs.isSymbolicLink
            ? 'l'
            : '-';

    String triple(bool read, bool write, bool execute) =>
        '${read ? 'r' : '-'}${write ? 'w' : '-'}${execute ? 'x' : '-'}';

    return type +
        triple(mode.userRead, mode.userWrite, mode.userExecute) +
        triple(mode.groupRead, mode.groupWrite, mode.groupExecute) +
        triple(mode.otherRead, mode.otherWrite, mode.otherExecute);
  }

  @override
  Future<Uint8List> readFile(String path, {int? maxBytes}) async {
    final sftp = await _sftpClient();
    final file = await sftp.open(path);
    try {
      return await file.readBytes(length: maxBytes);
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> writeFile(String path, Uint8List contents) async {
    final sftp = await _sftpClient();
    final file = await sftp.open(
      path,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.truncate | SftpFileOpenMode.write,
    );
    try {
      await file.writeBytes(contents);
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int, int)? onProgress,
  }) async {
    final source = File(localPath);
    final total = await source.length();

    final sftp = await _sftpClient();
    final file = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.truncate | SftpFileOpenMode.write,
    );

    try {
      final writer = file.write(
        source.openRead().map(Uint8List.fromList),
        onProgress: (sent) => onProgress?.call(sent, total),
      );
      await writer.done;
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int, int)? onProgress,
  }) async {
    final sftp = await _sftpClient();
    final attrs = await sftp.stat(remotePath);
    final total = attrs.size ?? 0;

    final destination = File(localPath);
    await destination.parent.create(recursive: true);
    final sink = destination.openWrite();

    try {
      await sftp.download(
        remotePath,
        sink,
        onProgress: (received) => onProgress?.call(received, total),
      );
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  @override
  Future<void> createDirectory(String path) async {
    final sftp = await _sftpClient();
    await sftp.mkdir(path);
  }

  @override
  Future<void> delete(String path, {bool recursive = false}) async {
    final sftp = await _sftpClient();
    final attrs = await sftp.stat(path);

    if (!attrs.isDirectory) {
      await sftp.remove(path);
      return;
    }

    if (!recursive) {
      await sftp.rmdir(path);
      return;
    }

    // SFTP has no recursive remove, so walk the tree depth-first. This is
    // deliberately not `rm -rf`: the path never reaches a shell, so a name
    // containing spaces or quotes cannot turn into extra arguments.
    for (final entry in await listDirectory(path)) {
      if (entry.name == '..') continue;
      await delete(entry.path, recursive: true);
    }
    await sftp.rmdir(path);
  }

  @override
  Future<void> rename(String oldPath, String newPath) async {
    final sftp = await _sftpClient();
    await sftp.rename(oldPath, newPath);
  }

  @override
  Future<void> chmod(String path, int mode) async {
    final sftp = await _sftpClient();
    await sftp.setStat(path, SftpFileAttrs(mode: SftpFileMode.value(mode)));
  }

  @override
  Future<ShellSession> openShell({int columns = 80, int rows = 24}) async {
    final client = _client;
    if (client == null || !_connected) {
      throw StateError('SSH session is not connected');
    }

    final session = await client.shell(
      pty: SSHPtyConfig(
        type: 'xterm-256color',
        width: columns,
        height: rows,
      ),
    );

    return _SshShellSession(session);
  }

  @override
  Future<void> disconnect() async {
    await _closeQuietly();
    _connected = false;
    logInfo('SSH session disconnected');
  }

  Future<void> _closeQuietly() async {
    try {
      _sftp?.close();
    } catch (_) {
      // Already gone.
    }
    _sftp = null;

    try {
      _client?.close();
    } catch (_) {
      // Already gone.
    }
    _client = null;

    try {
      _socket?.close();
    } catch (_) {
      // Already gone.
    }
    _socket = null;
  }
}

class _SshShellSession implements ShellSession {
  _SshShellSession(this._session) {
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
