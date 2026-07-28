import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final masterPasswordSet = ref.watch(masterPasswordSetProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'Security',
            children: [
              masterPasswordSet.when(
                data: (isSet) => SwitchListTile(
                  title: const Text('Master Password'),
                  subtitle: Text(isSet ? 'Encryption is active' : 'Set master password for encryption'),
                  value: isSet,
                  onChanged: (value) {
                    if (!isSet) {
                      _showMasterPasswordDialog();
                    }
                  },
                  activeColor: AppTheme.successGreen,
                ),
                loading: () => const ListTile(title: Text('Loading...')),
                error: (_, __) => const ListTile(title: Text('Error checking encryption status')),
              ),
              SwitchListTile(
                title: const Text('Biometric Unlock'),
                subtitle: const Text('Use fingerprint or face to unlock'),
                value: false,
                onChanged: (_) {},
                activeColor: AppTheme.successGreen,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Monitoring',
            children: [
              SwitchListTile(
                title: const Text('Background Monitoring'),
                subtitle: const Text('Collect metrics in the background'),
                value: false,
                onChanged: (_) {},
                activeColor: AppTheme.successGreen,
              ),
              ListTile(
                title: const Text('Refresh Interval'),
                subtitle: const Text('60 seconds'),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                onTap: () {},
              ),
              ListTile(
                title: const Text('Metric Retention'),
                subtitle: const Text('7 days'),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Notifications',
            children: [
              SwitchListTile(
                title: const Text('Push Notifications'),
                subtitle: const Text('Receive alerts and updates'),
                value: true,
                onChanged: (_) {},
                activeColor: AppTheme.successGreen,
              ),
              SwitchListTile(
                title: const Text('Alert Notifications'),
                subtitle: const Text('Notify on new alerts'),
                value: true,
                onChanged: (_) {},
                activeColor: AppTheme.successGreen,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Appearance',
            children: [
              ListTile(
                title: const Text('Theme'),
                subtitle: const Text('Dark'),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                onTap: () {},
              ),
              ListTile(
                title: const Text('Terminal Font Size'),
                subtitle: const Text('13px'),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'About',
            children: [
              const ListTile(
                title: Text('Version'),
                subtitle: Text('1.0.0'),
              ),
              ListTile(
                title: const Text('Open Source Licenses'),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 1)),
        const SizedBox(height: 4),
        Card(child: Column(children: children)),
      ],
    );
  }

  void _showMasterPasswordDialog() {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Master Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final pw = passwordController.text;
              final confirm = confirmController.text;
              if (pw.isEmpty || pw != confirm) return;

              final encryption = ref.read(encryptionServiceProvider);
              await encryption.setMasterPassword(pw);
              ref.invalidate(masterPasswordSetProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Set Password'),
          ),
        ],
      ),
    );
  }
}
