import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'sftp_provider.dart';

/// Reading and writing file contents.
class SshSftpTransfers {
  const SshSftpTransfers(this._sftp);

  final SftpProvider _sftp;

  /// Read in fixed chunks rather than pulling the whole file into memory — a
  /// log file on a busy server is routinely larger than a phone wants to hold.
  static const chunkSize = 64 * 1024;

  Future<Uint8List> readFile(String path, {int? maxBytes}) async {
    final sftp = await _sftp();
    final file = await sftp.open(path);
    try {
      return await file.readBytes(length: maxBytes);
    } finally {
      await file.close();
    }
  }

  Future<void> writeFile(String path, Uint8List contents) async {
    final file = await _openForWrite(path);
    try {
      await file.writeBytes(contents);
    } finally {
      await file.close();
    }
  }

  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int, int)? onProgress,
  }) async {
    final source = File(localPath);
    final total = await source.length();
    final file = await _openForWrite(remotePath);

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

  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int, int)? onProgress,
  }) async {
    final sftp = await _sftp();
    final total = (await sftp.stat(remotePath)).size ?? 0;

    final destination = File(localPath);
    await destination.parent.create(recursive: true);
    final sink = destination.openWrite();
    final file = await sftp.open(remotePath);

    try {
      var offset = 0;
      while (true) {
        final chunk = await file.readBytes(length: chunkSize, offset: offset);
        if (chunk.isEmpty) break;

        sink.add(chunk);
        offset += chunk.length;
        onProgress?.call(offset, total);

        // A short read means end of file.
        if (chunk.length < chunkSize) break;
      }
    } finally {
      await file.close();
      await sink.flush();
      await sink.close();
    }
  }

  Future<SftpFile> _openForWrite(String path) async {
    final sftp = await _sftp();
    return sftp.open(
      path,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.truncate | SftpFileOpenMode.write,
    );
  }
}
