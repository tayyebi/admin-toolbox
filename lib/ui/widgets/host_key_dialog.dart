import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/transport/ssh_client.dart';
import 'fingerprint_block.dart';
import 'host_key_explanation.dart';

export 'show_host_key_prompt.dart';

/// Asks the user whether to trust a server's host key.
///

class HostKeyDialog extends StatefulWidget {
  const HostKeyDialog({required this.prompt, super.key});

  final HostKeyPrompt prompt;

  @override
  State<HostKeyDialog> createState() => HostKeyDialogState();
}

class HostKeyDialogState extends State<HostKeyDialog> {
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
            Text(hostKeyExplanation(prompt), style: context.text.bodyMedium),
            const SizedBox(height: 16),

            if (isMismatch) ...[
              FingerprintBlock(
                label: 'Previously trusted',
                value: prompt.pinnedFingerprint!,
                color: colors.success,
              ),
              const SizedBox(height: 8),
            ],
            FingerprintBlock(
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
