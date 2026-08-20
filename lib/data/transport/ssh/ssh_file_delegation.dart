import 'dart:typed_data';

import '../file_entry.dart';
import 'ssh_file_operations.dart';

/// Routes the transport contract's file half to [SshFileOperations].
///
/// A mixin rather than inline methods so the session file is about the
/// connection's lifetime, not about restating ten signatures.
mixin SshFileDelegation {
  /// Null until connected; every method here throws through it deliberately,
  /// since a file operation on a closed session is a caller bug.
  SshFileOperations? get files;

  SshFileOperations get _files {
    final operations = files;
    if (operations == null) throw StateError('SSH session is not connected');
    return operations;
  }

  Future<List<FileEntry>> listDirectory(String path) => _files.listDirectory(path);

  Future<Uint8List> readFile(String path, {int? maxBytes}) =>
      _files.readFile(path, maxBytes: maxBytes);

  Future<void> writeFile(String path, Uint8List contents) => _files.writeFile(path, contents);

  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int, int)? onProgress,
  }) =>
      _files.uploadFile(localPath, remotePath, onProgress: onProgress);

  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int, int)? onProgress,
  }) =>
      _files.downloadFile(remotePath, localPath, onProgress: onProgress);

  Future<void> createDirectory(String path) => _files.createDirectory(path);

  Future<void> delete(String path, {bool recursive = false}) =>
      _files.delete(path, recursive: recursive);

  Future<void> rename(String oldPath, String newPath) => _files.rename(oldPath, newPath);

  Future<void> chmod(String path, int mode) => _files.chmod(path, mode);
}
