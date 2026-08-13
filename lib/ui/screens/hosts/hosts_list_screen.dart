import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/host.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/status_badge.dart';

class HostsListScreen extends ConsumerStatefulWidget {
  const HostsListScreen({super.key});

  @override
  ConsumerState<HostsListScreen> createState() => _HostsListScreenState();
}

class _HostsListScreenState extends ConsumerState<HostsListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hostsAsync =
        _query.isEmpty ? ref.watch(hostsProvider) : ref.watch(hostSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hosts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add host',
            onPressed: () => context.push('/hosts/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, hostname or tag',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
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
            child: hostsAsync.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(hostsProvider),
              ),
              data: (hosts) {
                if (hosts.isEmpty) {
                  return EmptyState(
                    icon: Icons.dns_outlined,
                    title: _query.isEmpty ? 'No hosts yet' : 'No hosts match "$_query"',
                    message: _query.isEmpty
                        ? 'Add a server, attach a credential from the vault, '
                            'and you can connect.'
                        : null,
                    actionLabel: _query.isEmpty ? 'Add host' : null,
                    onAction: _query.isEmpty ? () => context.push('/hosts/new') : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(hostsProvider);
                    ref.invalidate(hostStatusCountsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: hosts.length,
                    itemBuilder: (context, index) => _HostCard(host: hosts[index]),
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

class _HostCard extends ConsumerWidget {
  const _HostCard({required this.host});

  final Host host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final statusColor = colors.status(host.status);

    return Card(
      child: InkWell(
        onTap: () => context.push('/hosts/${host.id}'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.dns_outlined, color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.name,
                      style: context.text.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      host.endpoint,
                      style: AppTypography.monoSmall(colors.textMuted),
                    ),
                    if (host.identityId == null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.key_off_outlined, size: 12, color: colors.warning),
                          const SizedBox(width: 4),
                          Text(
                            'No credential',
                            style: context.text.labelSmall?.copyWith(color: colors.warning),
                          ),
                        ],
                      ),
                    ],
                    if (host.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final tag in host.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.scheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: context.text.labelSmall
                                      ?.copyWith(color: context.scheme.primary),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(status: host.status),
                  const SizedBox(height: 6),
                  if (host.monitoringPaused)
                    Icon(Icons.pause_circle_outline, size: 15, color: colors.textMuted),
                  if (host.favorite) ...[
                    if (host.monitoringPaused) const SizedBox(height: 4),
                    Icon(Icons.star, size: 15, color: colors.warning),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
