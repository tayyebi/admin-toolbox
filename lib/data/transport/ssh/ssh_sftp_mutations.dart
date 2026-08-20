import 'package:dartssh2/dartssh2.dart';

import 'sftp_provider.dart';
import 'ssh_sftp_browser.dart';

/// Creating, moving, removing and re-permissioning paths.
class SshSftpMutations {
  const SshSftpMutations(this._sftp, this._browser);

  final SftpProvider _sftp;
  final SshSftpBrowser _browser;

  Future<void> createDirectory(String path) async => (await _sftp()).mkdir(path);

  Future<void> rename(String oldPath, String newPath) async =>
      (await _sftp()).rename(oldPath, newPath);

  Future<void> chmod(String path, int mode) async =>
      (await _sftp()).setStat(path, SftpFileAttrs(mode: SftpFileMode.value(mode)));

  Future<void> delete(String path, {bool recursive = false}) async {
    final sftp = await _sftp();
    final attrs = await sftp.stat(path);

    if (!attrs.isDirectory) return sftp.remove(path);
    if (!recursive) return sftp.rmdir(path);

    // SFTP has no recursive remove, so walk the tree depth-first. This is
    // deliberately not `rm -rf`: the path never reaches a shell, so a name
    // containing spaces or quotes cannot turn into extra arguments.
    for (final entry in await _browser.listDirectory(path)) {
      if (entry.name == '..') continue;
      await delete(entry.path, recursive: true);
    }
    await sftp.rmdir(path);
  }
}
