import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/app_lock_controller.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/logger.dart';
import '../../../providers/providers.dart';

/// The gate in front of everything. Until this screen succeeds, no host,
/// credential or metric is readable.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();

  bool _obscure = true;
  bool _promptedBiometrics = false;
  Timer? _lockoutTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptBiometrics());
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    _passwordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Offers the biometric prompt once per appearance — re-prompting on every
  /// rebuild would trap the user in a dialog loop they cannot cancel out of.
  Future<void> _maybePromptBiometrics() async {
    if (_promptedBiometrics) return;
    final lock = ref.read(appLockProvider);
    final settings = ref.read(settingsProvider);
    if (!settings.biometricUnlock || !lock.canUseBiometrics) return;

    _promptedBiometrics = true;
    final unlocked = await ref.read(appLockProvider.notifier).unlockWithBiometrics();
    if (unlocked) await _afterUnlock();
  }

  Future<void> _submitPassword() async {
    if (_passwordController.text.isEmpty) return;
    final unlocked = await ref.read(appLockProvider.notifier).unlock(_passwordController.text);

    if (unlocked) {
      _passwordController.clear();
      await _afterUnlock();
    } else {
      _startLockoutTicker();
      _focusNode.requestFocus();
    }
  }

  /// Upgrading v1 records needs both the legacy key and the new one, which is
  /// true only in the moment right after unlocking.
  Future<void> _afterUnlock() async {
    try {
      final result = await ref.read(vaultMigrationProvider).migrate();
      if (result.hadWork) {
        ref.invalidate(identitiesProvider);
        if (result.hasFailures && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${result.failed} credential(s) could not be migrated and must '
                'be re-entered in the vault.',
              ),
            ),
          );
        }
      }
    } catch (e, stack) {
      logError('Vault migration failed', e, stack);
    }
  }

  /// Keeps the countdown label live while a back-off is in effect.
  void _startLockoutTicker() {
    _lockoutTicker?.cancel();
    if (!ref.read(appLockProvider).isLockedOut) return;
    _lockoutTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !ref.read(appLockProvider).isLockedOut) {
        timer.cancel();
        _lockoutTicker = null;
      }
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    final settings = ref.watch(settingsProvider);
    final lockedOut = lock.isLockedOut;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline, size: 44, color: context.scheme.primary),
                  const SizedBox(height: 20),
                  Text(
                    'Vault locked',
                    style: context.text.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your master password to continue.',
                    style: context.text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  TextField(
                    controller: _passwordController,
                    focusNode: _focusNode,
                    obscureText: _obscure,
                    autofocus: true,
                    enabled: !lockedOut && !lock.busy,
                    onSubmitted: (_) => _submitPassword(),
                    decoration: InputDecoration(
                      labelText: 'Master password',
                      errorText: lockedOut ? null : lock.error,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),

                  if (lockedOut) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Too many attempts. Try again in '
                      '${lock.lockoutRemaining.inSeconds}s.',
                      style: context.text.bodySmall?.copyWith(color: context.colors.danger),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: lock.busy || lockedOut ? null : _submitPassword,
                    child: lock.busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Unlock'),
                  ),

                  if (settings.biometricUnlock && lock.canUseBiometrics) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: lock.busy || lockedOut
                          ? null
                          : () async {
                              final ok = await ref
                                  .read(appLockProvider.notifier)
                                  .unlockWithBiometrics();
                              if (ok) await _afterUnlock();
                            },
                      icon: const Icon(Icons.fingerprint, size: 20),
                      label: const Text('Use biometrics'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
