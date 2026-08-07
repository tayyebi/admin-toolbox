import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/automation.dart';
import '../../../providers/providers.dart';

class AutomationFormScreen extends ConsumerStatefulWidget {
  const AutomationFormScreen({super.key, this.automationId});

  final String? automationId;

  @override
  ConsumerState<AutomationFormScreen> createState() => _AutomationFormScreenState();
}

class _AutomationFormScreenState extends ConsumerState<AutomationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();

  final List<_StepDraft> _steps = [_StepDraft()];
  final List<_StepDraft> _rollbackSteps = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.automationId != null) _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    for (final step in [..._steps, ..._rollbackSteps]) {
      step.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final automation =
        await ref.read(automationRepositoryProvider).getById(widget.automationId!);
    if (automation == null || !mounted) return;

    setState(() {
      _nameController.text = automation.name;
      _descriptionController.text = automation.description ?? '';
      _categoryController.text = automation.category ?? '';

      _steps
        ..clear()
        ..addAll(automation.steps.map(_StepDraft.from));
      if (_steps.isEmpty) _steps.add(_StepDraft());

      _rollbackSteps
        ..clear()
        ..addAll((automation.rollbackSteps ?? const []).map(_StepDraft.from));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final steps = _steps
        .where((s) => s.controller.text.trim().isNotEmpty)
        .map((s) => s.toStep())
        .toList();

    if (steps.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least one step')));
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(automationRepositoryProvider);
      final now = DateTime.now();
      final rollback = _rollbackSteps
          .where((s) => s.controller.text.trim().isNotEmpty)
          .map((s) => s.toStep())
          .toList();

      final automation = Automation(
        id: widget.automationId ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        description:
            _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
        steps: steps,
        rollbackSteps: rollback.isEmpty ? null : rollback,
        createdAt: now,
        updatedAt: now,
      );

      if (widget.automationId != null) {
        await repo.update(automation);
      } else {
        await repo.insert(automation);
      }

      ref.invalidate(automationsProvider);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.automationId != null ? 'Edit procedure' : 'New procedure'),
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
                hintText: 'e.g. Rolling nginx restart',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),

            const SizedBox(height: 28),
            _SectionHeader(
              title: 'Steps',
              subtitle: 'Run in order. A failing step stops the run unless you '
                  'mark it as continue-on-failure.',
              onAdd: () => setState(() => _steps.add(_StepDraft())),
            ),
            for (var i = 0; i < _steps.length; i++)
              _StepEditor(
                key: ObjectKey(_steps[i]),
                draft: _steps[i],
                index: i + 1,
                onRemove: _steps.length > 1
                    ? () => setState(() => _steps.removeAt(i).dispose())
                    : null,
                onChanged: () => setState(() {}),
              ),

            const SizedBox(height: 28),
            _SectionHeader(
              title: 'Rollback steps',
              subtitle: 'Optional. Run in reverse when a step fails, to undo '
                  'what already succeeded.',
              onAdd: () => setState(() => _rollbackSteps.add(_StepDraft())),
            ),
            if (_rollbackSteps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No rollback configured.',
                  style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
                ),
              ),
            for (var i = 0; i < _rollbackSteps.length; i++)
              _StepEditor(
                key: ObjectKey(_rollbackSteps[i]),
                draft: _rollbackSteps[i],
                index: i + 1,
                onRemove: () => setState(() => _rollbackSteps.removeAt(i).dispose()),
                onChanged: () => setState(() {}),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepDraft {
  _StepDraft({String command = '', this.continueOnFailure = false, this.timeoutSeconds = 60})
      : controller = TextEditingController(text: command);

  factory _StepDraft.from(AutomationStep step) => _StepDraft(
        command: step.command,
        continueOnFailure: step.continueOnFailure,
        timeoutSeconds: step.timeout.inSeconds,
      );

  final TextEditingController controller;
  bool continueOnFailure;
  int timeoutSeconds;

  AutomationStep toStep() => AutomationStep(
        command: controller.text.trim(),
        continueOnFailure: continueOnFailure,
        timeout: Duration(seconds: timeoutSeconds),
      );

  void dispose() => controller.dispose();
}

class _StepEditor extends StatelessWidget {
  const _StepEditor({
    super.key,
    required this.draft,
    required this.index,
    required this.onChanged,
    this.onRemove,
  });

  final _StepDraft draft;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Step $index', style: context.text.titleSmall),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onRemove,
                  ),
              ],
            ),
            TextFormField(
              controller: draft.controller,
              decoration: const InputDecoration(
                hintText: 'systemctl restart {{service}}',
                isDense: true,
              ),
              style: AppTypography.monoStyle(size: 12, color: context.scheme.onSurface),
              maxLines: 3,
              minLines: 1,
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    value: draft.continueOnFailure,
                    onChanged: (value) {
                      draft.continueOnFailure = value ?? false;
                      onChanged();
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('Continue on failure', style: context.text.bodySmall),
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: TextFormField(
                    initialValue: '${draft.timeoutSeconds}',
                    decoration: const InputDecoration(
                      labelText: 'Timeout',
                      suffixText: 's',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => draft.timeoutSeconds = int.tryParse(value) ?? 60,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
