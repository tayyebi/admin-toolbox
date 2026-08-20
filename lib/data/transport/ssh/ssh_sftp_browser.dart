import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import '../file_entry.dart';
import 'sftp_provider.dart';

/// Directory listing.
class SshSftpBrowser {
  const SshSftpBrowser(this._sftp);

  final SftpProvider _sftp;

  Future<List<FileEntry>> listDirectory(String path) async {
    final sftp = await _sftp();
    final names = await sftp.listdir(path);

    final entries = <FileEntry>[];
    for (final name in names) {
      if (name.filename == '.') continue;
      entries.add(_toEntry(name, path));
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

  static FileEntry _toEntry(SftpName name, String parent) {
    final attrs = name.attr;
    return FileEntry(
      name: name.filename,
      path: name.filename == '..' ? p.dirname(parent) : p.join(parent, name.filename),
      isDirectory: attrs.isDirectory,
      isSymlink: attrs.isSymbolicLink,
      size: attrs.size ?? 0,
      modifiedAt: attrs.modifyTime != null
          ? DateTime.fromMillisecondsSinceEpoch(attrs.modifyTime! * 1000)
          : DateTime.fromMillisecondsSinceEpoch(0),
      permissions: permissionString(attrs),
      mode: attrs.mode?.value,
    );
  }

  /// The `drwxr-xr-x` form.
  static String permissionString(SftpFileAttrs attrs) {
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
}
