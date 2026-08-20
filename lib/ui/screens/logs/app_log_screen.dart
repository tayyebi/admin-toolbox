import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/log_entry.dart';
import '../../../data/repositories/log_repository.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';

class AppLogScreen extends ConsumerStatefulWidget {
  const AppLogScreen({super.key});

  @override
  ConsumerState<AppLogScreen> createState() => _AppLogScreenState();
}

class _AppLogScreenState extends ConsumerState<AppLogScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final content = await ref.read(logRepositoryProvider).exportAsJsonl();
    if (content.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to share')));
      }
      return;
    }
    await ref.read(auditRepositoryProvider).log(action: 'share_app_logs', entityType: 'app_log');
    await Share.share(content, subject: 'Admin Toolbox app log');
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all logs?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(logRepositoryProvider).clear();
    await ref.read(auditRepositoryProvider).log(action: 'clear_app_logs', entityType: 'app_log');
    ref.invalidate(logSearchProvider(_query));
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(logSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('App logs'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share, size: 20),
            onPressed: _share,
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: _clear,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search level or message',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          Expanded(
            child: entries.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(logSearchProvider(_query)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.bug_report_outlined,
                    title: _query.isEmpty ? 'No logs captured yet' : 'No matches',
                    message: _query.isEmpty
                        ? 'Diagnostic output from the app is recorded here.'
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(logSearchProvider(_query)),
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: context.colors.border),
                    itemBuilder: (context, index) => _LogTile(entry: items[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final LogEntry entry;

  (Color, IconData) _appearance(BuildContext context) {
    final colors = context.colors;
    switch (entry.level) {
      case 'error':
        return (colors.danger, Icons.error_outline);
      case 'warning':
        return (colors.warning, Icons.warning_amber_outlined);
      case 'debug':
        return (colors.textMuted, Icons.bug_report_outlined);
      default:
        return (colors.info, Icons.info_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _appearance(context);

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: color),
      title: Text(
        entry.message,
        style: AppTypography.monoSmall(context.scheme.onSurface),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${entry.level.toUpperCase()} · ${entry.timestamp.timeAgo}',
        style: context.text.labelSmall?.copyWith(color: context.colors.textMuted),
      ),
    );
  }
}
