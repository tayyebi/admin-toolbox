import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';
import '../../widgets/status_badge.dart';

class HostsListScreen extends ConsumerStatefulWidget {
  const HostsListScreen({super.key});

  @override
  ConsumerState<HostsListScreen> createState() => _HostsListScreenState();
}

class _HostsListScreenState extends ConsumerState<HostsListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final hostsAsync = _searchQuery.isEmpty
        ? ref.watch(hostsProvider)
        : ref.watch(hostSearchProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hosts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Host',
            onPressed: () => context.push('/hosts/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search hosts...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: hostsAsync.when(
              data: (hosts) {
                if (hosts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.computer, size: 64, color: AppTheme.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No hosts configured' : 'No hosts match "$_searchQuery"',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/hosts/new'),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Host'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(hostsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: hosts.length,
                    itemBuilder: (context, index) {
                      final host = hosts[index];
                      return _HostCard(host: host);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostCard extends ConsumerWidget {
  final dynamic host;

  const _HostCard({required this.host});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = AppTheme.statusColor(host.status ?? 'unknown');

    return Card(
      child: InkWell(
        onTap: () => context.push('/hosts/${host.id}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.computer, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.name ?? host.hostname,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${host.hostname}:${host.port}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    if ((host.tags as List?)?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          children: (host.tags as List).map<Widget>((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('$tag', style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue)),
                              )).toList(),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(status: host.status ?? 'unknown'),
                  const SizedBox(height: 4),
                  if (host.favorite == true)
                    const Icon(Icons.star, size: 16, color: AppTheme.warningOrange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
