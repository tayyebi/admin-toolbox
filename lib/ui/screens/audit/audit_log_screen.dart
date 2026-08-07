import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/audit_entry.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';

final _auditChainProvider = FutureProvider<AuditChainStatus>((ref) async {
  return ref.watch(auditRepositoryProvider).verifyChain();
});

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final content = await ref.read(auditRepositoryProvider).exportAsJsonl();
    if (content.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Nothing to export')));
      }
      return;
    }
    await Share.share(content, subject: 'Admin Toolbox audit log');
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(auditSearchProvider(_query));
    final chain = ref.watch(_auditChainProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit log'),
        actions: [
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share, size: 20),
            onPressed: _export,
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
                hintText: 'Search actions, entities, details',
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

          chain.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (status) => _ChainBanner(status: status),
          ),

          Expanded(
            child: entries.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(auditSearchProvider(_query)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: _query.isEmpty ? 'No activity recorded yet' : 'No matches',
                    message: _query.isEmpty
                        ? 'Every change and connection is recorded here.'
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(auditSearchProvider(_query));
                    ref.invalidate(_auditChainProvider);
                  },
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: context.colors.border),
                    itemBuilder: (context, index) => _AuditTile(entry: items[index]),
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

class _ChainBanner extends StatelessWidget {
  const _ChainBanner({required this.status});

  final AuditChainStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (color, icon, message) = status.intact
        ? (
            colors.success,
            Icons.verified_outlined,
            status.unverifiableCount > 0
                ? '${status.verifiedCount} of ${status.totalCount} records verified '
                    '(${status.unverifiableCount} predate hash chaining)'
                : 'All ${status.totalCount} records verified',
          )
        : (
            colors.danger,
            Icons.gpp_bad_outlined,
            'Chain broken after ${status.verifiedCount} records — '
                'the log has been modified',
          );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: context.text.bodySmall?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final AuditEntry entry;

  /// Destructive and security-relevant actions read differently at a glance.
  Color _accent(BuildContext context) {
    final colors = context.colors;
    if (entry.action.contains('delete')) return colors.danger;
    if (entry.action.contains('reveal') || entry.action.contains('unlock')) {
      return colors.warning;
    }
    if (entry.action.contains('create')) return colors.success;
    return colors.info;
  }

  IconData get _icon {
    if (entry.action.contains('delete')) return Icons.delete_outline;
    if (entry.action.contains('create')) return Icons.add_circle_outline;
    if (entry.action.contains('update')) return Icons.edit_outlined;
    if (entry.action.contains('reveal')) return Icons.visibility_outlined;
    if (entry.action.contains('terminal')) return Icons.terminal;
    if (entry.action.startsWith('file_')) return Icons.folder_outlined;
    if (entry.action.contains('automation')) return Icons.play_circle_outline;
    return Icons.circle_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);

    return ListTile(
      dense: true,
      leading: Icon(_icon, size: 20, color: accent),
      title: Text(
        '${entry.action.replaceAll('_', ' ').capitalize} · ${entry.entityType}',
        style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurface),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.details != null && entry.details!.isNotEmpty)
            Text(
              entry.details!,
              style: AppTypography.monoSmall(context.colors.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            entry.timestamp.timeAgo,
            style: context.text.labelSmall?.copyWith(color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}
