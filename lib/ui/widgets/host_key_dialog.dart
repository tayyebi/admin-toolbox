import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/transport/ssh_client.dart';
import '../routes.dart';

/// Asks the user whether to trust a server's host key.
///
/// Two very different situations share this dialog, and they are styled
/// differently on purpose. An unknown key is routine — you see it the first
/// time you connect anywhere. A *changed* key means the server is not the one
/// you pinned, which is either a rebuild or an interception, and the dialog
/// should not let that slide past as another "OK".
Future<bool> showHostKeyPrompt(HostKeyPrompt prompt) async {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return false;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _HostKeyDialog(prompt: prompt),
  );
  return accepted ?? false;
}

class _HostKeyDialog extends StatefulWidget {
  const _HostKeyDialog({required this.prompt});

  final HostKeyPrompt prompt;

  @override
  State<_HostKeyDialog> createState() => _HostKeyDialogState();
}

class _HostKeyDialogState extends State<_HostKeyDialog> {
  /// Required before a *changed* key can be accepted, so the dangerous case
  /// cannot be dismissed by muscle memory.
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final prompt = widget.prompt;
    final colors = context.colors;
    final isMismatch = prompt.isMismatch;
    final accent = isMismatch ? colors.danger : colors.warning;

    return AlertDialog(
      icon: Icon(isMismatch ? Icons.gpp_bad_outlined : Icons.gpp_maybe_outlined,
          color: accent, size: 32),
      title: Text(isMismatch ? 'Host key has changed' : 'Unknown host key'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMismatch
                  ? 'The key presented by ${prompt.hostname}:${prompt.port} does '
                      'not match the one you trusted before. This happens when a '
                      'server is rebuilt — but it is also exactly what a '
                      'machine-in-the-middle attack looks like.'
                  : 'You have not connected to ${prompt.hostname}:${prompt.port} '
                      'before. Check the fingerprint matches what the server '
                      'reports from `ssh-keygen -lf /etc/ssh/ssh_host_*_key.pub`.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: 16),

            if (isMismatch) ...[
              _FingerprintBlock(
                label: 'Previously trusted',
                value: prompt.pinnedFingerprint!,
                color: colors.success,
              ),
              const SizedBox(height: 8),
            ],
            _FingerprintBlock(
              label: isMismatch ? 'Presented now' : 'Fingerprint',
              value: prompt.fingerprint,
              color: accent,
            ),
            const SizedBox(height: 6),
            Text(
              'Key type: ${prompt.keyType}',
              style: context.text.bodySmall?.copyWith(color: colors.textMuted),
            ),

            if (isMismatch) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _understood,
                onChanged: (value) => setState(() => _understood = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'I verified this change out of band',
                  style: context.text.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: isMismatch
              ? FilledButton.styleFrom(backgroundColor: colors.danger)
              : null,
          onPressed: isMismatch && !_understood ? null : () => Navigator.pop(context, true),
          child: Text(isMismatch ? 'Replace pinned key' : 'Trust and connect'),
        ),
      ],
    );
  }
}

class _FingerprintBlock extends StatelessWidget {
  const _FingerprintBlock({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.labelSmall?.copyWith(color: context.colors.textMuted),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: SelectableText(
            value,
            style: AppTypography.monoStyle(size: 11, color: context.scheme.onSurface),
          ),
        ),
      ],
    );
  }
}
