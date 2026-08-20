import 'dart:typed_data';

import '../file_entry.dart';
import 'sftp_provider.dart';
import 'ssh_sftp_browser.dart';
import 'ssh_sftp_mutations.dart';
import 'ssh_sftp_transfers.dart';

/// Everything the transport contract asks of SFTP, over one shared channel.
class SshFileOperations {
  SshFileOperations(SftpProvider sftp)
      : _browser = SshSftpBrowser(sftp),
        _transfers = SshSftpTransfers(sftp),
        _mutations = SshSftpMutations(sftp, SshSftpBrowser(sftp));

  final SshSftpBrowser _browser;
  final SshSftpTransfers _transfers;
  final SshSftpMutations _mutations;

  Future<List<FileEntry>> listDirectory(String path) => _browser.listDirectory(path);

  Future<Uint8List> readFile(String path, {int? maxBytes}) =>
      _transfers.readFile(path, maxBytes: maxBytes);

  Future<void> writeFile(String path, Uint8List contents) =>
      _transfers.writeFile(path, contents);

  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int, int)? onProgress,
  }) =>
      _transfers.uploadFile(localPath, remotePath, onProgress: onProgress);

  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int, int)? onProgress,
  }) =>
      _transfers.downloadFile(remotePath, localPath, onProgress: onProgress);

  Future<void> createDirectory(String path) => _mutations.createDirectory(path);

  Future<void> delete(String path, {bool recursive = false}) =>
      _mutations.delete(path, recursive: recursive);

  Future<void> rename(String oldPath, String newPath) => _mutations.rename(oldPath, newPath);

  Future<void> chmod(String path, int mode) => _mutations.chmod(path, mode);
}
