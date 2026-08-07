import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/command.dart';
import '../../../providers/providers.dart';

class CommandFormScreen extends ConsumerStatefulWidget {
  const CommandFormScreen({super.key, this.commandId});

  final String? commandId;

  @override
  ConsumerState<CommandFormScreen> createState() => _CommandFormScreenState();
}

class _CommandFormScreenState extends ConsumerState<CommandFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _commandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _commandController.addListener(() => setState(() {}));
    if (widget.commandId != null) _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final command = await ref.read(commandRepositoryProvider).getById(widget.commandId!);
    if (command == null || !mounted) return;
    setState(() {
      _nameController.text = command.name;
      _commandController.text = command.command;
      _descriptionController.text = command.description ?? '';
      _categoryController.text = command.category ?? '';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(commandRepositoryProvider);
      final now = DateTime.now();
      final text = _commandController.text.trim();

      final command = Command(
        id: widget.commandId ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        command: text,
        description:
            _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
        // Derived from the command text rather than entered separately, so the
        // two cannot drift apart when the command is edited.
        variables: Command.placeholdersIn(text),
        createdAt: now,
        updatedAt: now,
      );

      if (widget.commandId != null) {
        await repo.update(command);
      } else {
        await repo.insert(command);
      }

      ref.invalidate(commandsProvider);
      ref.invalidate(favoriteCommandsProvider);
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

  @override
  Widget build(BuildContext context) {
    final placeholders = Command.placeholdersIn(_commandController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.commandId != null ? 'Edit command' : 'New command'),
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
                labelText: 'Name',
                hintText: 'e.g. Restart nginx',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _commandController,
              decoration: const InputDecoration(
                labelText: 'Command',
                hintText: 'systemctl restart {{service}}',
                alignLabelWithHint: true,
              ),
              style: AppTypography.monoStyle(size: 12, color: context.scheme.onSurface),
              maxLines: 5,
              minLines: 2,
              autocorrect: false,
              enableSuggestions: false,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            if (placeholders.isEmpty)
              Text(
                'Wrap changing parts in {{double braces}} to be prompted for '
                'them at run time.',
                style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    'Variables:',
                    style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
                  ),
                  for (final name in placeholders)
                    Chip(
                      label: Text(name),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'e.g. Services, Diagnostics',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}
