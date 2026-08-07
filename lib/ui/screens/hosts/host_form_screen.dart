import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/host.dart';
import '../../../data/transport/connection_manager.dart';
import '../../../data/transport/ssh_client.dart';
import '../../../data/transport/transport.dart';
import '../../../providers/providers.dart';
import '../../widgets/host_key_dialog.dart';

class HostFormScreen extends ConsumerStatefulWidget {
  const HostFormScreen({super.key, this.hostId});

  final String? hostId;

  @override
  ConsumerState<HostFormScreen> createState() => _HostFormScreenState();
}

class _HostFormScreenState extends ConsumerState<HostFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostnameController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();

  String? _identityId;
  String? _groupId;

  bool _isEditing = false;
  bool _saving = false;
  bool _testing = false;
  _TestOutcome? _testOutcome;

  @override
  void initState() {
    super.initState();
    if (widget.hostId != null) {
      _isEditing = true;
      _load();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostnameController.dispose();
    _portController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final host = await ref.read(hostRepositoryProvider).getById(widget.hostId!);
    if (host == null || !mounted) return;

    setState(() {
      _nameController.text = host.name;
      _hostnameController.text = host.hostname;
      _portController.text = host.port.toString();
      _notesController.text = host.notes ?? '';
      _tagsController.text = host.tags.join(', ');
      _identityId = host.identityId;
      _groupId = host.groupId;
    });
  }

  Host _buildHost() {
    final now = DateTime.now();
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    return Host(
      id: widget.hostId ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      hostname: _hostnameController.text.trim(),
      port: int.tryParse(_portController.text) ?? 22,
      identityId: _identityId,
      groupId: _groupId,
      tags: tags,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(hostRepositoryProvider);
      final host = _buildHost();

      if (_isEditing) {
        final existing = await repo.getById(widget.hostId!);
        if (existing != null) {
          await repo.update(
            existing.copyWith(
              name: host.name,
              hostname: host.hostname,
              port: host.port,
              identityId: _identityId,
              groupId: _groupId,
              tags: host.tags,
              notes: host.notes,
              updatedAt: DateTime.now(),
            ),
          );
        }
      } else {
        await repo.insert(host);
      }

      await ref.read(auditRepositoryProvider).log(
            action: _isEditing ? 'update' : 'create',
            entityType: 'host',
            entityId: host.id,
            hostId: host.id,
            details: '${host.name} (${host.endpoint})',
          );

      ref.invalidate(hostsProvider);
      ref.invalidate(hostStatusCountsProvider);
      ref.invalidate(identityUsageProvider);
      if (widget.hostId != null) ref.invalidate(hostDetailProvider(widget.hostId!));

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Opens a real connection and runs one trivial command.
  ///
  /// Worth doing before saving: it surfaces a wrong port, a missing identity
  /// or an untrusted host key here, rather than as a host that silently sits
  /// at "offline" forever.
  Future<void> _testConnection() async {
    if (_hostnameController.text.trim().isEmpty) {
      setState(() => _testOutcome = const _TestOutcome(false, 'Enter a hostname first.'));
      return;
    }
    if (_identityId == null) {
      setState(() => _testOutcome =
          const _TestOutcome(false, 'Choose a credential from the vault first.'));
      return;
    }

    setState(() {
      _testing = true;
      _testOutcome = null;
    });

    final manager = ref.read(connectionManagerProvider);
    final previousPrompt = manager.onHostKeyPrompt;
    manager.onHostKeyPrompt = showHostKeyPrompt;

    final stopwatch = Stopwatch()..start();
    final host = _buildHost();

    try {
      // Bypass the pool: a test should always be a fresh handshake.
      final factory = SshTransportFactory(onHostKeyPrompt: showHostKeyPrompt);
      final identity = await ref.read(identityRepositoryProvider).getById(_identityId!);
      if (identity == null) {
        setState(() => _testOutcome = const _TestOutcome(false, 'That credential no longer exists.'));
        return;
      }

      final session = await factory.create(
        TransportConnectionConfig(
          host: host.hostname,
          port: host.port,
          username: identity.username,
          password: identity.password,
          privateKey: identity.privateKey,
          passphrase: identity.passphrase,
          connectTimeout: const Duration(seconds: 12),
        ),
      );

      final result = await session.execute('uname -sr', timeout: const Duration(seconds: 10));
      await session.disconnect();
      stopwatch.stop();

      final banner = result.stdout.trim();
      setState(() {
        _testOutcome = _TestOutcome(
          true,
          'Connected in ${stopwatch.elapsedMilliseconds} ms'
          '${banner.isEmpty ? '' : ' · $banner'}',
        );
      });
    } on HostKeyRejectedException catch (e) {
      stopwatch.stop();
      setState(() => _testOutcome = _TestOutcome(false, e.toString()));
    } catch (e) {
      stopwatch.stop();
      setState(() => _testOutcome = _TestOutcome(false, _friendlyError(e)));
    } finally {
      manager.onHostKeyPrompt = previousPrompt;
      if (mounted) setState(() => _testing = false);
    }
  }

  static String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Connection refused')) {
      return 'Could not reach the host. Check the address, port and firewall.';
    }
    if (text.contains('TimeoutException') || text.contains('timed out')) {
      return 'The connection timed out.';
    }
    if (text.toLowerCase().contains('auth')) {
      return 'The server rejected these credentials.';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final identities = ref.watch(identitiesProvider);
    final groups = ref.watch(groupsProvider);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit host' : 'New host'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'e.g. Web Server 01',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _hostnameController,
                    decoration: const InputDecoration(
                      labelText: 'Hostname or IP',
                      hintText: 'server.example.com',
                    ),
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    style: AppTypography.monoStyle(color: context.scheme.onSurface),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(labelText: 'Port'),
                    keyboardType: TextInputType.number,
                    style: AppTypography.monoStyle(color: context.scheme.onSurface),
                    validator: (v) {
                      final port = int.tryParse(v ?? '');
                      if (port == null || port < 1 || port > 65535) return '1–65535';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Without this the app cannot authenticate at all — every host
            // stayed permanently offline because nothing ever set identityId.
            identities.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                'Could not load the vault: $e',
                style: context.text.bodySmall?.copyWith(color: colors.danger),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.key_off_outlined, color: colors.warning),
                      title: const Text('No credentials in the vault'),
                      subtitle: const Text('Add an SSH key or password to connect.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/vault/new'),
                    ),
                  );
                }

                return DropdownButtonFormField<String?>(
                  value: items.any((i) => i.id == _identityId) ? _identityId : null,
                  decoration: const InputDecoration(labelText: 'Credential'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...items.map(
                      (identity) => DropdownMenuItem(
                        value: identity.id,
                        child: Text(
                          '${identity.name} · ${identity.username}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _identityId = value;
                    _testOutcome = null;
                  }),
                );
              },
            ),
            const SizedBox(height: 16),

            groups.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (items) => DropdownButtonFormField<String?>(
                value: items.any((g) => g.id == _groupId) ? _groupId : null,
                decoration: const InputDecoration(labelText: 'Group'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Ungrouped')),
                  ...items.map(
                    (group) => DropdownMenuItem(value: group.id, child: Text(group.name)),
                  ),
                ],
                onChanged: (value) => setState(() => _groupId = value),
              ),
            ),
            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.network_check, size: 18),
              label: Text(_testing ? 'Connecting…' : 'Test connection'),
            ),

            if (_testOutcome != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_testOutcome!.success ? colors.success : colors.danger)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (_testOutcome!.success ? colors.success : colors.danger)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testOutcome!.success ? Icons.check_circle_outline : Icons.error_outline,
                      size: 18,
                      color: _testOutcome!.success ? colors.success : colors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_testOutcome!.message, style: context.text.bodySmall),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'production, web, nginx',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}

class _TestOutcome {
  const _TestOutcome(this.success, this.message);
  final bool success;
  final String message;
}
