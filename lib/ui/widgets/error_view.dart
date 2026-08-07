import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Standard failure state.
///
/// Replaces the `Text('Error: $e')` that used to appear in a dozen screens —
/// which gave the user a raw exception and no way forward.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.title = 'Something went wrong',
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final String title;
  final VoidCallback? onRetry;

  /// Renders inline inside a card rather than filling the screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (!compact) ...[
          Icon(Icons.error_outline, size: 40, color: context.colors.danger),
          const SizedBox(height: 12),
        ],
        Text(
          title,
          style: context.text.titleMedium,
          textAlign: compact ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _describe(error),
          style: context.text.bodySmall,
          textAlign: compact ? TextAlign.start : TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ],
    );

    if (compact) return Padding(padding: const EdgeInsets.all(16), child: content);
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: content));
  }

  /// Turns known exceptions into something a user can act on, and falls back to
  /// the raw message otherwise.
  static String _describe(Object error) {
    final text = error.toString();
    if (text.contains('Vault is locked')) {
      return 'The vault is locked. Unlock it to read stored credentials.';
    }
    if (text.contains('Failed to decrypt')) {
      return 'A stored credential could not be decrypted. It may have been '
          'written with a different master password.';
    }
    return text.replaceFirst('Exception: ', '');
  }
}

/// Standard empty state: an icon, a line explaining the absence, and — where
/// there is one — the action that fills it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.colors.textMuted),
            const SizedBox(height: 16),
            Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centred spinner sized for a full screen body.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
    );
  }
}
