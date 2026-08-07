import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/app_lock_controller.dart';
import '../../../core/theme/app_colors.dart';

/// First-run screen: creates the vault that protects every stored credential.
class VaultSetupScreen extends ConsumerStatefulWidget {
  const VaultSetupScreen({super.key});

  @override
  ConsumerState<VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends ConsumerState<VaultSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure = true;
  bool _acknowledged = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_acknowledged) return;
    await ref.read(appLockProvider.notifier).setUp(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    final strength = _PasswordStrength.of(_passwordController.text);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.shield_outlined, size: 44, color: context.scheme.primary),
                    const SizedBox(height: 20),
                    Text(
                      'Create your vault',
                      style: context.text.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your master password encrypts every SSH key and password '
                      'this app stores. It never leaves the device.',
                      style: context.text.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Master password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 10) {
                          return 'Use at least 10 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _StrengthBar(strength: strength),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscure,
                      decoration: const InputDecoration(labelText: 'Confirm password'),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) {
                        if (value != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // This is the one thing the user cannot undo later, so it
                    // takes a deliberate acknowledgement rather than fine print.
                    CheckboxListTile(
                      value: _acknowledged,
                      onChanged: (value) => setState(() => _acknowledged = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'I understand this password cannot be recovered',
                        style: context.text.bodySmall,
                      ),
                      subtitle: Text(
                        'There is no reset. If you forget it, stored credentials are lost.',
                        style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
                      ),
                    ),

                    if (lock.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        lock.error!,
                        style: context.text.bodySmall?.copyWith(color: context.colors.danger),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: lock.busy || !_acknowledged ? null : _submit,
                      child: lock.busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create vault'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rough four-level classification. Deliberately simple: it nudges toward
/// longer passphrases without pretending to be an entropy estimator.
class _PasswordStrength {
  const _PasswordStrength(this.level, this.label);

  final int level; // 0-4
  final String label;

  static _PasswordStrength of(String value) {
    if (value.isEmpty) return const _PasswordStrength(0, '');
    var score = 0;
    if (value.length >= 10) score++;
    if (value.length >= 16) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value) && RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;

    switch (score) {
      case 0:
      case 1:
        return const _PasswordStrength(1, 'Weak');
      case 2:
        return const _PasswordStrength(2, 'Fair');
      case 3:
        return const _PasswordStrength(3, 'Good');
      default:
        return const _PasswordStrength(4, 'Strong');
    }
  }
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.strength});

  final _PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (strength.level) {
      1 => colors.danger,
      2 => colors.warning,
      3 => colors.info,
      4 => colors.success,
      _ => colors.border,
    };

    return Row(
      children: [
        for (var i = 1; i <= 4; i++) ...[
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: i <= strength.level ? color : colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < 4) const SizedBox(width: 4),
        ],
        const SizedBox(width: 10),
        SizedBox(
          width: 48,
          child: Text(
            strength.label,
            style: context.text.labelSmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
