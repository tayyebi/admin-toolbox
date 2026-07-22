import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/host.dart';
import '../../../data/repositories/host_repository.dart';
import '../../../providers/providers.dart';

class HostFormScreen extends ConsumerStatefulWidget {
  final String? hostId;

  const HostFormScreen({super.key, this.hostId});

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

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.hostId != null) {
      _isEditing = true;
      _loadHost();
    }
  }

  Future<void> _loadHost() async {
    final repo = ref.read(hostRepositoryProvider);
    final host = await repo.getById(widget.hostId!);
    if (host != null) {
      setState(() {
        _nameController.text = host.name;
        _hostnameController.text = host.hostname;
        _portController.text = host.port.toString();
        _notesController.text = host.notes ?? '';
        _tagsController.text = host.tags.join(', ');
      });
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final repo = ref.read(hostRepositoryProvider);
    final now = DateTime.now();
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (_isEditing) {
      final existing = await repo.getById(widget.hostId!);
      if (existing != null) {
        await repo.update(existing.copyWith(
          name: _nameController.text,
          hostname: _hostnameController.text,
          port: int.tryParse(_portController.text) ?? 22,
          notes: _notesController.text,
          tags: tags,
          updatedAt: now,
        ));
      }
    } else {
      await repo.insert(Host(
        id: const Uuid().v4(),
        name: _nameController.text,
        hostname: _hostnameController.text,
        port: int.tryParse(_portController.text) ?? 22,
        tags: tags,
        notes: _notesController.text,
        createdAt: now,
        updatedAt: now,
      ));
    }

    ref.invalidate(hostsProvider);

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Host' : 'New Host'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'e.g., Web Server 01',
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hostnameController,
              decoration: const InputDecoration(
                labelText: 'Hostname / IP',
                hintText: 'e.g., 192.168.1.100 or server.example.com',
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final port = int.tryParse(v ?? '');
                if (port == null || port < 1 || port > 65535) {
                  return 'Invalid port (1-65535)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma separated)',
                hintText: 'e.g., production, web, nginx',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Any additional information...',
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}
