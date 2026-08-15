import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/identity.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';

/// The credential vault: every SSH key and password the app can authenticate
/// with. Renders from unencrypted metadata only — names, key types and
/// fingerprints — so the list never decrypts a secret it does not need.
class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identities = ref.watch(identitiesProvider);
    final usage = ref.watch(identityUsageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add credential',
            onPressed: () => context.push('/vault/new'),
          ),
        ],
      ),
      body: identities.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          title: 'Could not read the vault',
          onRetry: () => ref.invalidate(identitiesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.key_outlined,
              title: 'No credentials yet',
              message: 'Add an SSH key or password here, then attach it to a '
                  'host so the app can connect.',
              actionLabel: 'Add credential',
              onAction: () => context.push('/vault/new'),
            );
          }

          final counts = usage.valueOrNull ?? const <String, int>{};

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(identitiesProvider);
              ref.invalidate(identityUsageProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final identity = items[index];
                return _IdentityTile(
                  identity: identity,
                  hostCount: counts[identity.id] ?? 0,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _IdentityTile extends StatelessWidget {
  const _IdentityTile({required this.identity, required this.hostCount});

  final Identity identity;
  final int hostCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isKey = identity.isKeyBased;
    final accent = isKey ? context.scheme.primary : colors.warning;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push('/vault/${identity.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(isKey ? Icons.vpn_key_outlined : Icons.password_outlined,
                    color: accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            identity.name,
                            style: context.text.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TypeBadge(label: identity.keyType ?? identity.type.label, color: accent),
                      ],
                    ),
                    if (identity.fingerprint != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        identity.shortFingerprint,
                        style: AppTypography.monoSmall(colors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.dns_outlined, size: 13, color: colors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          hostCount == 1 ? '1 host' : '$hostCount hosts',
                          style: context.text.labelSmall?.copyWith(color: colors.textMuted),
                        ),
                        if (identity.lastUsedAt != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.schedule, size: 13, color: colors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'used ${identity.lastUsedAt!.timeAgo}',
                            style: context.text.labelSmall?.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
