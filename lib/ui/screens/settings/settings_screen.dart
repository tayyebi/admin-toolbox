import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/security/app_lock_controller.dart';
import '../../../core/security/secure_display.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../modules/alerting/notification_service.dart';
import '../../../providers/providers.dart';

final _packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final lock = ref.watch(appLockProvider);
    final packageInfo = ref.watch(_packageInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _Section(
            title: 'Appearance',
            children: [
              ListTile(
                title: const Text('Theme'),
                subtitle: Text(switch (settings.themeMode) {
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                  ThemeMode.system => 'Follow system',
                }),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _pickTheme(context, ref, settings.themeMode),
              ),
              ListTile(
                title: const Text('Terminal font size'),
                subtitle: Text('${settings.terminalFontSize.toStringAsFixed(0)} pt'),
                trailing: SizedBox(
                  width: 160,
                  child: Slider(
                    value: settings.terminalFontSize,
                    min: 9,
                    max: 22,
                    divisions: 13,
                    label: settings.terminalFontSize.toStringAsFixed(0),
                    onChanged: controller.setTerminalFontSize,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.colors.terminalBackground,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r'admin@web-01:~$ systemctl status nginx',
                    style: AppTypography.monoTerminal(
                      context.colors.terminalForeground,
                      settings.terminalFontSize,
                    ),
                  ),
                ),
              ),
            ],
          ),

          _Section(
            title: 'Security',
            children: [
              SwitchListTile(
                title: const Text('Biometric unlock'),
                subtitle: Text(
                  lock.biometricAvailable
                      ? 'Unlock the vault with fingerprint or face'
                      : 'No biometric hardware enrolled on this device',
                ),
                value: settings.biometricUnlock && lock.biometricConfigured,
                onChanged: lock.biometricAvailable
                    ? (enabled) async {
                        final lockController = ref.read(appLockProvider.notifier);
                        if (enabled) {
                          await lockController.enableBiometricUnlock();
                        } else {
                          await lockController.disableBiometricUnlock();
                        }
                        await controller.setBiometricUnlock(enabled);
                      }
                    : null,
              ),
              ListTile(
                title: const Text('Auto-lock'),
                subtitle: Text(_describeAutoLock(settings.autoLockDelay)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _pickAutoLock(context, ref, settings.autoLockDelay),
              ),
              SwitchListTile(
                title: const Text('Block screenshots'),
                subtitle: const Text(
                  'Hides the app from screenshots and the task switcher',
                ),
                value: settings.blockScreenshots,
                onChanged: (enabled) async {
                  await controller.setBlockScreenshots(enabled);
                  await SecureDisplay.setSecure(enabled);
                },
              ),
              ListTile(
                title: const Text('Change master password'),
                subtitle: const Text('Stored credentials are not re-encrypted'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _changeMasterPassword(context, ref),
              ),
              ListTile(
                title: const Text('Lock now'),
                leading: const Icon(Icons.lock_outline),
                onTap: () => ref.read(appLockProvider.notifier).lock(),
              ),
            ],
          ),

          _Section(
            title: 'Monitoring',
            children: [
              SwitchListTile(
                title: const Text('Background monitoring'),
                subtitle: const Text('Collect metrics while the app is open'),
                value: settings.backgroundMonitoring,
                onChanged: (enabled) async {
                  await controller.setBackgroundMonitoring(enabled);
                  final monitoring = ref.read(monitoringServiceProvider);
                  if (enabled) {
                    await monitoring.startMonitoring(
                      interval: settings.monitoringInterval,
                      retentionDays: settings.metricRetentionDays,
                    );
                  } else {
                    monitoring.stopMonitoring();
                  }
                  ref.read(isMonitoringProvider.notifier).state = enabled;
                },
              ),
              ListTile(
                title: const Text('Collection interval'),
                subtitle: Text('${settings.monitoringInterval.inSeconds} seconds'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _pickInterval(context, ref, settings.monitoringInterval),
              ),
              ListTile(
                title: const Text('Metric retention'),
                subtitle: Text('${settings.metricRetentionDays} days'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _pickRetention(context, ref, settings.metricRetentionDays),
              ),
              ListTile(
                title: const Text('Purge old metrics now'),
                leading: const Icon(Icons.cleaning_services_outlined),
                onTap: () async {
                  final removed =
                      await ref.read(monitoringServiceProvider).purgeOldMetrics();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Removed $removed metric records')),
                    );
                  }
                },
              ),
            ],
          ),

          _Section(
            title: 'Notifications',
            children: [
              SwitchListTile(
                title: const Text('Alert notifications'),
                subtitle: const Text('Notify when a rule threshold is breached'),
                value: settings.alertNotifications,
                onChanged: (enabled) async {
                  if (enabled) {
                    final granted = await NotificationService.instance.requestPermission();
                    if (!granted && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notification permission was not granted'),
                        ),
                      );
                      return;
                    }
                  }
                  NotificationService.instance.setEnabled(enabled);
                  await controller.setAlertNotifications(enabled);
                },
              ),
            ],
          ),

          _Section(
            title: 'About',
            children: [
              ListTile(
                title: const Text('Version'),
                subtitle: Text(
                  packageInfo.when(
                    data: (info) => '${info.version} (${info.buildNumber})',
                    loading: () => '…',
                    error: (_, __) => 'unknown',
                  ),
                ),
              ),
              ListTile(
                title: const Text('Open source licences'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Admin Toolbox',
                  applicationVersion: packageInfo.valueOrNull?.version,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _describeAutoLock(Duration delay) {
    if (delay <= Duration.zero) return 'Immediately';
    if (delay.inMinutes < 60) return 'After ${delay.inMinutes} minutes';
    return 'After ${delay.inHours} hour${delay.inHours == 1 ? '' : 's'}';
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref, ThemeMode current) async {
    final mode = await _pickOption<ThemeMode>(
      context,
      title: 'Theme',
      current: current,
      options: const [
        (value: ThemeMode.system, label: 'Follow system'),
        (value: ThemeMode.light, label: 'Light'),
        (value: ThemeMode.dark, label: 'Dark'),
      ],
    );
    if (mode != null) await ref.read(settingsProvider.notifier).setThemeMode(mode);
  }

  Future<void> _pickAutoLock(BuildContext context, WidgetRef ref, Duration current) async {
    final delay = await _pickOption<Duration>(
      context,
      title: 'Auto-lock',
      current: current,
      options: const [
        (value: Duration.zero, label: 'Immediately'),
        (value: Duration(minutes: 1), label: 'After 1 minute'),
        (value: Duration(minutes: 5), label: 'After 5 minutes'),
        (value: Duration(minutes: 15), label: 'After 15 minutes'),
        (value: Duration(hours: 1), label: 'After 1 hour'),
      ],
    );
    if (delay != null) await ref.read(settingsProvider.notifier).setAutoLockDelay(delay);
  }

  Future<void> _pickInterval(BuildContext context, WidgetRef ref, Duration current) async {
    final interval = await _pickOption<Duration>(
      context,
      title: 'Collection interval',
      current: current,
      options: const [
        (value: Duration(seconds: 30), label: '30 seconds'),
        (value: Duration(seconds: 60), label: '1 minute'),
        (value: Duration(minutes: 5), label: '5 minutes'),
        (value: Duration(minutes: 15), label: '15 minutes'),
      ],
    );
    if (interval == null) return;

    await ref.read(settingsProvider.notifier).setMonitoringInterval(interval);

    // Restart so the new interval takes effect rather than waiting for the
    // next app launch.
    final monitoring = ref.read(monitoringServiceProvider);
    if (monitoring.isRunning) {
      monitoring.stopMonitoring();
      await monitoring.startMonitoring(
        interval: interval,
        retentionDays: ref.read(settingsProvider).metricRetentionDays,
      );
    }
  }

  Future<void> _pickRetention(BuildContext context, WidgetRef ref, int current) async {
    final days = await _pickOption<int>(
      context,
      title: 'Metric retention',
      current: current,
      options: const [
        (value: 1, label: '1 day'),
        (value: 7, label: '7 days'),
        (value: 30, label: '30 days'),
        (value: 90, label: '90 days'),
      ],
    );
    if (days == null) return;

    await ref.read(settingsProvider.notifier).setMetricRetentionDays(days);
    ref.read(monitoringServiceProvider).setRetentionDays(days);
  }

  Future<T?> _pickOption<T>(
    BuildContext context, {
    required String title,
    required T current,
    required List<({T value, String label})> options,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: context.text.titleLarge),
              ),
            ),
            for (final option in options)
              RadioListTile<T>(
                value: option.value,
                groupValue: current,
                title: Text(option.label),
                onChanged: (value) => Navigator.pop(sheetContext, value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _changeMasterPassword(BuildContext context, WidgetRef ref) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change master password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (newController.text.length < 10 ||
                  newController.text != confirmController.text) {
                return;
              }
              final ok = await ref.read(encryptionServiceProvider).changePassword(
                    currentController.text,
                    newController.text,
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext, ok);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();

    if (context.mounted && changed != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changed ? 'Master password changed' : 'The current password was incorrect',
          ),
        ),
      );
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              title.toUpperCase(),
              style: context.text.labelSmall?.copyWith(
                color: context.colors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Card(
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
