import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/logger.dart';
import '../../../data/transport/connection_manager.dart';
import '../../../data/transport/transport.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/host_key_dialog.dart';

/// Remote file management over SFTP.
///
/// Replaces a screen that listed seven hardcoded fake files and whose menu did
/// nothing. Paths are passed to SFTP calls directly rather than interpolated
/// into shell commands, so a filename containing a space or a quote cannot
/// turn into extra arguments.
class FileBrowserScreen extends ConsumerStatefulWidget {
  const FileBrowserScreen({super.key, required this.hostId});

  final String hostId;

  @override
  ConsumerState<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends ConsumerState<FileBrowserScreen> {
  static const _maxEditableBytes = 512 * 1024;

  String _path = '.';
  List<FileEntry> _entries = const [];
  bool _loading = true;
  bool _showHidden = false;
  String? _error;
  double? _transferProgress;

  TransportSession? _session;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    final host = ref.read(hostDetailProvider(widget.hostId)).valueOrNull;
    if (host != null) ref.read(connectionManagerProvider).release(host);
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final host = await ref.read(hostRepositoryProvider).getById(widget.hostId);
      if (host == null) throw StateError('Host not found');

      final manager = ref.read(connectionManagerProvider)..onHostKeyPrompt = showHostKeyPrompt;
      _session = await manager.acquire(host);

      // Start in the login user's home directory rather than guessing a path.
      final home = await _session!.execute('pwd', timeout: const Duration(seconds: 10));
      _path = home.isSuccess && home.stdout.trim().isNotEmpty ? home.stdout.trim() : '/';

      await _list(_path);
    } catch (e, stack) {
      logError('Could not open file browser', e, stack);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _list(String path) async {
    final session = _session;
    if (session == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = await session.listDirectory(path);
      if (!mounted) return;
      setState(() {
        _path = path;
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not list $path: $e';
      });
    }
  }

  List<FileEntry> get _visibleEntries =>
      _showHidden ? _entries : _entries.where((e) => !e.isHidden || e.name == '..').toList();

  Future<void> _openEntry(FileEntry entry) async {
    if (entry.isDirectory) {
      await _list(entry.name == '..' ? p.dirname(_path) : entry.path);
      return;
    }

    if (entry.size > _maxEditableBytes) {
      final download = await _confirm(
        title: 'Large file',
        message: '${entry.name} is ${formatBytes(entry.size)}. Download it '
            'instead of opening it here?',
        confirmLabel: 'Download',
      );
      if (download) await _download(entry);
      return;
    }

    await _viewFile(entry);
  }

  Future<void> _viewFile(FileEntry entry) async {
    final session = _session;
    if (session == null) return;

    try {
      final bytes = await session.readFile(entry.path, maxBytes: _maxEditableBytes);
      final text = utf8.decode(bytes, allowMalformed: true);
      if (!mounted) return;

      final edited = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => _FileEditorScreen(name: entry.name, initialContent: text),
        ),
      );

      if (edited != null) {
        await session.writeFile(entry.path, Uint8List.fromList(utf8.encode(edited)));
        await ref.read(auditRepositoryProvider).log(
              action: 'file_write',
              entityType: 'file',
              hostId: widget.hostId,
              details: entry.path,
            );
        _notify('Saved ${entry.name}');
        await _list(_path);
      }
    } catch (e) {
      _notify('Could not open ${entry.name}: $e');
    }
  }

  Future<void> _download(FileEntry entry) async {
    final session = _session;
    if (session == null) return;

    setState(() => _transferProgress = 0);
    try {
      final directory = await getTemporaryDirectory();
      final localPath = p.join(directory.path, entry.name);

      await session.downloadFile(
        entry.path,
        localPath,
        onProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() => _transferProgress = received / total);
          }
        },
      );

      await ref.read(auditRepositoryProvider).log(
            action: 'file_download',
            entityType: 'file',
            hostId: widget.hostId,
            details: entry.path,
          );

      if (!mounted) return;
      setState(() => _transferProgress = null);
      await Share.shareXFiles([XFile(localPath)], subject: entry.name);
    } catch (e) {
      if (mounted) setState(() => _transferProgress = null);
      _notify('Download failed: $e');
    }
  }

  Future<void> _upload() async {
    final session = _session;
    if (session == null) return;

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final localPath = picked.path;
    if (localPath == null) {
      _notify('That file could not be read.');
      return;
    }

    setState(() => _transferProgress = 0);
    try {
      await session.uploadFile(
        localPath,
        p.join(_path, picked.name),
        onProgress: (sent, total) {
          if (mounted && total > 0) setState(() => _transferProgress = sent / total);
        },
      );

      await ref.read(auditRepositoryProvider).log(
            action: 'file_upload',
            entityType: 'file',
            hostId: widget.hostId,
            details: p.join(_path, picked.name),
          );

      if (mounted) setState(() => _transferProgress = null);
      _notify('Uploaded ${picked.name}');
      await _list(_path);
    } catch (e) {
      if (mounted) setState(() => _transferProgress = null);
      _notify('Upload failed: $e');
    }
  }

  Future<void> _createDirectory() async {
    final name = await _promptForText(title: 'New folder', label: 'Folder name');
    if (name == null || name.trim().isEmpty) return;

    try {
      await _session?.createDirectory(p.join(_path, name.trim()));
      await _list(_path);
    } catch (e) {
      _notify('Could not create folder: $e');
    }
  }

  Future<void> _rename(FileEntry entry) async {
    final name = await _promptForText(
      title: 'Rename',
      label: 'New name',
      initialValue: entry.name,
    );
    if (name == null || name.trim().isEmpty || name.trim() == entry.name) return;

    try {
      await _session?.rename(entry.path, p.join(p.dirname(entry.path), name.trim()));
      await _list(_path);
    } catch (e) {
      _notify('Rename failed: $e');
    }
  }

  Future<void> _delete(FileEntry entry) async {
    final confirmed = await _confirm(
      title: 'Delete ${entry.name}?',
      message: entry.isDirectory
          ? 'This deletes the folder and everything inside it. This cannot be undone.'
          : 'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await _session?.delete(entry.path, recursive: entry.isDirectory);
      await ref.read(auditRepositoryProvider).log(
            action: 'file_delete',
            entityType: 'file',
            hostId: widget.hostId,
            details: entry.path,
          );
      await _list(_path);
    } catch (e) {
      _notify('Delete failed: $e');
    }
  }

  Future<void> _changePermissions(FileEntry entry) async {
    final current = entry.mode == null
        ? ''
        : (entry.mode! & 0x1FF).toRadixString(8).padLeft(3, '0');

    final value = await _promptForText(
      title: 'Permissions',
      label: 'Octal mode',
      initialValue: current,
      hint: 'e.g. 644 or 755',
    );
    if (value == null) return;

    final mode = int.tryParse(value.trim(), radix: 8);
    if (mode == null || mode < 0 || mode > 0x1FF) {
      _notify('Enter a three-digit octal mode, such as 644.');
      return;
    }

    try {
      await _session?.chmod(entry.path, mode);
      await _list(_path);
    } catch (e) {
      _notify('Could not change permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(hostDetailProvider(widget.hostId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(host?.name ?? 'Files'),
        actions: [
          IconButton(
            tooltip: 'Upload',
            icon: const Icon(Icons.upload_file, size: 20),
            onPressed: _session == null ? null : _upload,
          ),
          IconButton(
            tooltip: 'New folder',
            icon: const Icon(Icons.create_new_folder_outlined, size: 20),
            onPressed: _session == null ? null : _createDirectory,
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              switch (action) {
                case 'hidden':
                  setState(() => _showHidden = !_showHidden);
                case 'refresh':
                  unawaited(_list(_path));
                case 'root':
                  unawaited(_list('/'));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'hidden',
                child: Text(_showHidden ? 'Hide hidden files' : 'Show hidden files'),
              ),
              const PopupMenuItem(value: 'root', child: Text('Go to /')),
              const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _PathBar(path: _path, onNavigate: _list),
          if (_transferProgress != null)
            LinearProgressIndicator(value: _transferProgress),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const LoadingView();

    if (_error != null) {
      return ErrorView(error: _error!, title: 'File browser', onRetry: _open);
    }

    final entries = _visibleEntries;
    if (entries.isEmpty) {
      return const EmptyState(icon: Icons.folder_open, title: 'This folder is empty');
    }

    return RefreshIndicator(
      onRefresh: () => _list(_path),
      child: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: context.colors.border),
        itemBuilder: (context, index) => _FileTile(
          entry: entries[index],
          onTap: () => _openEntry(entries[index]),
          onAction: (action) {
            switch (action) {
              case 'rename':
                unawaited(_rename(entries[index]));
              case 'delete':
                unawaited(_delete(entries[index]));
              case 'permissions':
                unawaited(_changePermissions(entries[index]));
              case 'download':
                unawaited(_download(entries[index]));
            }
          },
        ),
      ),
    );
  }

  Future<String?> _promptForText({
    required String title,
    required String label,
    String? initialValue,
    String? hint,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: context.colors.danger)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PathBar extends StatelessWidget {
  const _PathBar({required this.path, required this.onNavigate});

  final String path;
  final Future<void> Function(String path) onNavigate;

  @override
  Widget build(BuildContext context) {
    final segments = p.split(path).where((s) => s.isNotEmpty && s != '/').toList();

    return Container(
      width: double.infinity,
      color: context.colors.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: [
            InkWell(
              onTap: () => onNavigate('/'),
              child: Icon(Icons.storage, size: 15, color: context.colors.textMuted),
            ),
            for (var i = 0; i < segments.length; i++) ...[
              Text(' / ', style: AppTypography.monoSmall(context.colors.textMuted)),
              InkWell(
                onTap: () => onNavigate('/${segments.sublist(0, i + 1).join('/')}'),
                child: Text(
                  segments[i],
                  style: AppTypography.monoSmall(
                    i == segments.length - 1
                        ? context.scheme.onSurface
                        : context.colors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.entry, required this.onTap, required this.onAction});

  final FileEntry entry;
  final VoidCallback onTap;
  final void Function(String action) onAction;

  IconData get _icon {
    if (entry.name == '..') return Icons.arrow_upward;
    if (entry.isDirectory) return Icons.folder;
    if (entry.isSymlink) return Icons.link;

    switch (p.extension(entry.name).toLowerCase()) {
      case '.sh':
      case '.bash':
      case '.zsh':
        return Icons.terminal;
      case '.conf':
      case '.cfg':
      case '.ini':
      case '.yaml':
      case '.yml':
      case '.json':
      case '.toml':
        return Icons.settings_outlined;
      case '.log':
        return Icons.article_outlined;
      case '.md':
      case '.txt':
        return Icons.description_outlined;
      case '.gz':
      case '.zip':
      case '.tar':
      case '.xz':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isParent = entry.name == '..';

    return ListTile(
      dense: true,
      leading: Icon(
        _icon,
        size: 20,
        color: entry.isDirectory ? colors.warning : colors.textMuted,
      ),
      title: Text(
        entry.name,
        style: context.text.bodyMedium?.copyWith(
          color: context.scheme.onSurface,
          fontWeight: entry.isDirectory ? FontWeight.w500 : FontWeight.w400,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: isParent
          ? null
          : Text(
              '${entry.permissions}  ${entry.isDirectory ? '' : formatBytes(entry.size)}'
              '${entry.modifiedAt.millisecondsSinceEpoch == 0 ? '' : '  ${entry.modifiedAt.timeAgo}'}',
              style: AppTypography.monoSmall(colors.textMuted),
            ),
      onTap: onTap,
      trailing: isParent
          ? null
          : PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, size: 18, color: colors.textMuted),
              onSelected: onAction,
              itemBuilder: (context) => [
                if (!entry.isDirectory)
                  const PopupMenuItem(value: 'download', child: Text('Download')),
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                const PopupMenuItem(value: 'permissions', child: Text('Permissions')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: colors.danger)),
                ),
              ],
            ),
    );
  }
}

/// Simple text editor for small remote files.
class _FileEditorScreen extends StatefulWidget {
  const _FileEditorScreen({required this.name, required this.initialContent});

  final String name;
  final String initialContent;

  @override
  State<_FileEditorScreen> createState() => _FileEditorScreenState();
}

class _FileEditorScreenState extends State<_FileEditorScreen> {
  late final TextEditingController _controller;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(() {
      final dirty = _controller.text != widget.initialContent;
      if (dirty != _dirty) setState(() => _dirty = dirty);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Discard changes?'),
            content: Text('${widget.name} has unsaved edits.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (discard == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.name),
          actions: [
            TextButton(
              onPressed: _dirty ? () => Navigator.pop(context, _controller.text) : null,
              child: const Text('Save'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _controller,
            maxLines: null,
            expands: true,
            autocorrect: false,
            enableSuggestions: false,
            textAlignVertical: TextAlignVertical.top,
            style: AppTypography.monoStyle(size: 12, color: context.scheme.onSurface),
            decoration: const InputDecoration(border: InputBorder.none, filled: false),
          ),
        ),
      ),
    );
  }
}
