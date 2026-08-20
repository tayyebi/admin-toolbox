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
