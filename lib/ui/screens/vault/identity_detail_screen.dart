import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/crypto/ssh_key_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/identity.dart';
import '../../../data/repositories/identity_repository.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/reauth_gate.dart';

class IdentityDetailScreen extends ConsumerStatefulWidget {
  const IdentityDetailScreen({super.key, required this.identityId});

  final String identityId;

  @override
  ConsumerState<IdentityDetailScreen> createState() => _IdentityDetailScreenState();
}

class _IdentityDetailScreenState extends ConsumerState<IdentityDetailScreen> {
  /// Only ever holds a secret while the user is actively looking at it.
  String? _revealedSecret;

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(identityDetailProvider(widget.identityId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credential'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/vault/${widget.identityId}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(identityAsync.valueOrNull),
          ),
        ],
      ),
      body: identityAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(identityDetailProvider(widget.identityId)),
        ),
        data: (identity) {
          if (identity == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Credential not found',
            );
          }
          return _buildBody(identity);
        },
      ),
    );
  }

  Widget _buildBody(Identity identity) {
    final colors = context.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(identity.name, style: context.text.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  identity.type.label,
                  style: context.text.bodyMedium,
                ),
                if (identity.comment != null) ...[
                  const SizedBox(height: 4),
                  Text(identity.comment!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
        ),

        if (identity.fingerprint != null)
          _InfoCard(
            title: 'Fingerprint',
            trailing: IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => _copy(identity.fingerprint!, 'Fingerprint copied'),
            ),
            child: SelectableText(
              identity.fingerprint!,
              style: AppTypography.monoSmall(context.scheme.onSurface),
            ),
          ),

        if (identity.publicKey != null) ...[
          _InfoCard(
            title: 'Public key',
            child: SelectableText(
              identity.publicKey!,
              style: AppTypography.monoStyle(size: 11, color: context.scheme.onSurface),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(identity.publicKey!, 'Public key copied'),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Share.share(
                    identity.publicKey!,
                    subject: '${identity.name} public key',
                  ),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showInstallCommand(identity),
            icon: const Icon(Icons.terminal, size: 18),
            label: const Text('Install on a host'),
          ),
          const SizedBox(height: 16),
        ],

        // Revealing a stored secret is a deliberate, re-authenticated act, and
        // it is recorded in the audit log.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 18, color: colors.textMuted),
                    const SizedBox(width: 8),
                    Text('Stored secret', style: context.text.titleSmall),
                  ],
                ),
                const SizedBox(height: 8),
                if (_revealedSecret == null)
                  Text(
                    identity.isKeyBased
                        ? 'The private key is encrypted at rest. Reveal it only '
                            'if you need to copy it elsewhere.'
                        : 'The password is encrypted at rest.',
                    style: context.text.bodySmall?.copyWith(color: colors.textMuted),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.border),
                    ),
                    child: SelectableText(
                      _revealedSecret!,
                      style: AppTypography.monoStyle(size: 11, color: context.scheme.onSurface),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_revealedSecret == null)
                  OutlinedButton.icon(
                    onPressed: () => _reveal(identity),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Reveal'),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copy(_revealedSecret!, 'Copied to clipboard'),
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _revealedSecret = null),
                          icon: const Icon(Icons.visibility_off_outlined, size: 18),
                          label: const Text('Hide'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),

        _InfoCard(
          title: 'Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Algorithm', value: identity.keyType ?? '—'),
              _DetailRow(label: 'Added', value: identity.createdAt.timeAgo),
              _DetailRow(
                label: 'Last used',
                value: identity.lastUsedAt?.timeAgo ?? 'Never',
              ),
              _DetailRow(
                label: 'Passphrase',
                value: identity.isKeyBased
                    ? (identity.hasPassphrase ? 'Protected' : 'None')
                    : '—',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _reveal(Identity identity) async {
    if (!await requireReauth(context, ref)) return;
    if (!mounted) return;

    try {
      final full = await ref.read(identityRepositoryProvider).getById(identity.id);
      if (full == null || !mounted) return;

      final secret = identity.isKeyBased ? full.privateKey : full.password;
      if (secret == null || secret.isEmpty) {
        _showMessage('No secret is stored for this credential.');
        return;
      }

      await ref.read(auditRepositoryProvider).log(
            action: 'reveal_secret',
            entityType: 'identity',
            entityId: identity.id,
            details: identity.name,
          );

      setState(() => _revealedSecret = secret);
    } catch (e) {
      if (mounted) _showMessage('Could not decrypt: $e');
    }
  }

  Future<void> _showInstallCommand(Identity identity) async {
    final command = SshKeyService.instance.authorizedKeyInstallCommand(identity.publicKey!);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Authorise this key', style: context.text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Run this on the host as the target user. It is safe to run '
              'twice — the key is only appended if it is not already there.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: context.colors.border),
              ),
              child: SelectableText(
                command,
                style: AppTypography.monoStyle(size: 11, color: context.scheme.onSurface),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                _copy(command, 'Command copied');
                Navigator.pop(sheetContext);
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy command'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Identity? identity) async {
    if (identity == null) return;

    final usageCount =
        await ref.read(identityRepositoryProvider).getHostUsageCount(identity.id);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete credential?'),
        content: Text(
          usageCount == 0
              ? 'This cannot be undone.'
              : 'This credential is attached to $usageCount host'
                  '${usageCount == 1 ? '' : 's'}, which will no longer be able '
                  'to connect. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(identityRepositoryProvider).delete(identity.id);
    await ref.read(auditRepositoryProvider).log(
          action: 'delete',
          entityType: 'identity',
          entityId: identity.id,
          details: identity.name,
        );

    ref.invalidate(identitiesProvider);
    ref.invalidate(identityUsageProvider);
    if (mounted) context.pop();
  }

  void _copy(String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, this.trailing, required this.child});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: context.text.titleSmall)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
            ),
          ),
          Expanded(child: Text(value, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}
