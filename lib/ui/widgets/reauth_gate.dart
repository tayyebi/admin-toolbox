import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/app_lock_controller.dart';
import '../../providers/providers.dart';

/// Re-confirms it is the device owner in front of the app, even though the
/// vault is already unlocked — for actions sensitive enough that a stale
/// unlocked session should not be enough on its own (revealing a stored
/// secret, viewing the verbose app log).
///
/// Prompts biometrics if configured, otherwise the master password. Returns
/// whether the check passed.
Future<bool> requireReauth(
  BuildContext context,
  WidgetRef ref, {
  String title = 'Confirm it is you',
}) async {
  final lock = ref.read(appLockProvider);
  if (lock.canUseBiometrics) {
    return ref.read(appLockProvider.notifier).unlockWithBiometrics();
  }
  if (!context.mounted) return false;
  return _confirmWithPassword(context, ref, title);
}

Future<bool> _confirmWithPassword(BuildContext context, WidgetRef ref, String title) async {
  final controller = TextEditingController();
  var isProcessing = false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          enabled: !isProcessing,
          decoration: const InputDecoration(labelText: 'Master password'),
        ),
        actions: [
          TextButton(
            onPressed: isProcessing ? null : () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: isProcessing
                ? null
                : () async {
                    setDialogState(() => isProcessing = true);
                    final ok = await ref.read(encryptionServiceProvider).unlock(controller.text);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, ok);
                    }
                  },
            child: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirm'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return confirmed ?? false;
}
