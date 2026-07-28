import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';

class FileBrowserScreen extends ConsumerWidget {
  final String hostId;

  const FileBrowserScreen({super.key, required this.hostId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostAsync = ref.watch(hostDetailProvider(hostId));

    return Scaffold(
      appBar: AppBar(
        title: hostAsync.when(
          data: (host) => Text('${host?.name ?? 'Host'} - Files'),
          loading: () => const Text('Files'),
          error: (_, __) => const Text('Files'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.upload_file), onPressed: () {}),
          IconButton(icon: const Icon(Icons.create_new_folder), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: AppTheme.bgSurface,
            child: const Row(
              children: [
                Icon(Icons.folder_open, color: AppTheme.textMuted, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '/home/admin/',
                    style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: const [
                _FileItem(icon: Icons.folder, name: '..', isDirectory: true),
                _FileItem(icon: Icons.folder, name: 'Documents', isDirectory: true),
                _FileItem(icon: Icons.folder, name: 'Downloads', isDirectory: true),
                _FileItem(icon: Icons.folder, name: 'Projects', isDirectory: true),
                _FileItem(icon: Icons.description, name: 'README.md', size: '2.1 KB', modified: '2024-01-15'),
                _FileItem(icon: Icons.code, name: 'config.yaml', size: '512 B', modified: '2024-01-14'),
                _FileItem(icon: Icons.insert_drive_file, name: 'script.sh', size: '1.3 KB', modified: '2024-01-13'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileItem extends StatelessWidget {
  final IconData icon;
  final String name;
  final bool isDirectory;
  final String? size;
  final String? modified;

  const _FileItem({
    required this.icon,
    required this.name,
    this.isDirectory = false,
    this.size,
    this.modified,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isDirectory ? AppTheme.warningOrange : AppTheme.textSecondary, size: 22),
      title: Text(name, style: TextStyle(fontSize: 13, color: isDirectory ? AppTheme.textPrimary : AppTheme.textSecondary)),
      subtitle: size != null ? Text('$size - $modified', style: const TextStyle(fontSize: 11)) : null,
      dense: true,
      trailing: PopupMenuButton(
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.dangerRed))),
          const PopupMenuItem(value: 'permissions', child: Text('Permissions')),
        ],
        icon: const Icon(Icons.more_horiz, size: 16),
      ),
    );
  }
}
