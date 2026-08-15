import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/ssh_key_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/identity.dart';
import '../../../providers/providers.dart';

enum _KeySource { paste, file, generate }

/// Create or edit a vault credential.
class IdentityFormScreen extends ConsumerStatefulWidget {
  const IdentityFormScreen({super.key, this.identityId});

  final String? identityId;

  @override
  ConsumerState<IdentityFormScreen> createState() => _IdentityFormScreenState();
}

class _IdentityFormScreenState extends ConsumerState<IdentityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _publicKeyController = TextEditingController();
  final _commentController = TextEditingController();

  IdentityType _type = IdentityType.sshKey;
  _KeySource _keySource = _KeySource.paste;
  int _generateBits = 2048;

  bool _isEditing = false;
  bool _loading = false;
  bool _saving = false;
  bool _generating = false;
  bool _obscureSecret = true;
  String? _keyStatus;
  bool _keyStatusIsError = false;

  @override
  void initState() {
    super.initState();
    if (widget.identityId != null) {
      _isEditing = true;
      _load();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _passphraseController.dispose();
    _publicKeyController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Editing needs the decrypted secrets, unlike the vault list.
      final identity = await ref.read(identityRepositoryProvider).getById(widget.identityId!);
      if (identity == null || !mounted) return;

      _nameController.text = identity.name;
      _passwordController.text = identity.password ?? '';
      _privateKeyController.text = identity.privateKey ?? '';
      _passphraseController.text = identity.passphrase ?? '';
      _publicKeyController.text = identity.publicKey ?? '';
      _commentController.text = identity.comment ?? '';
      setState(() => _type = identity.type);
    } catch (e) {
      if (mounted) _showMessage('Could not load this credential: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickKeyFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _showMessage('That file could not be read.');
      return;
    }

    try {
      _privateKeyController.text = utf8.decode(bytes);
      if (_commentController.text.isEmpty) _commentController.text = file.name;
      _validateKey();
    } on FormatException {
      _showMessage('That file is not a text private key.');
    }
  }

  /// Checks the key as typed, so a wrong passphrase is caught here rather than
  /// on a failed connection days later.
  void _validateKey() {
    final pem = _privateKeyController.text.trim();
    if (pem.isEmpty) {
      setState(() {
        _keyStatus = null;
        _keyStatusIsError = false;
      });
      return;
    }

    final inspection = SshKeyService.instance.inspect(
      pem,
      passphrase: _passphraseController.text.isEmpty ? null : _passphraseController.text,
    );

    setState(() {
      if (inspection.valid) {
        _keyStatus = 'Valid ${inspection.algorithm ?? 'SSH'} key';
        _keyStatusIsError = false;
      } else if (inspection.needsPassphrase) {
        _keyStatus = 'This key is passphrase-protected — enter the passphrase.';
        _keyStatusIsError = false;
      } else {
        _keyStatus = inspection.error ?? 'The key could not be read.';
        _keyStatusIsError = true;
      }
    });
  }

  Future<void> _generateKey() async {
    setState(() => _generating = true);
    try {
      final generated = await SshKeyService.instance.generateRsa(
        bits: _generateBits,
        comment: _commentController.text.trim().isEmpty
            ? 'admin-toolbox'
            : _commentController.text.trim(),
      );

      if (!mounted) return;
      _privateKeyController.text = generated.privateKeyPem;
      _publicKeyController.text = generated.publicKeyLine;
      _passphraseController.clear();
      setState(() {
        _keySource = _KeySource.paste;
        _keyStatus = 'Generated ${generated.bits}-bit RSA key '
            '(${generated.fingerprint})';
        _keyStatusIsError = false;
      });
    } catch (e) {
      if (mounted) _showMessage('Key generation failed: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final privateKey = _privateKeyController.text.trim();
    final passphrase = _passphraseController.text;

    if (_type == IdentityType.sshKey) {
      final inspection = SshKeyService.instance.inspect(
        privateKey,
        passphrase: passphrase.isEmpty ? null : passphrase,
      );
      if (!inspection.valid) {
        _showMessage(inspection.needsPassphrase
            ? 'Enter the passphrase for this key before saving.'
            : inspection.error ?? 'The key could not be read.');
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(identityRepositoryProvider);
      final publicKeyLine = _publicKeyController.text.trim();
      final now = DateTime.now();

      final identity = Identity(
        id: widget.identityId ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        type: _type,
        password: _type == IdentityType.password ? _passwordController.text : null,
        privateKey: _type == IdentityType.sshKey ? privateKey : null,
        passphrase: _type == IdentityType.sshKey && passphrase.isNotEmpty ? passphrase : null,
        keyType: publicKeyLine.isEmpty
            ? SshKeyService.instance.inspect(privateKey, passphrase: passphrase).algorithm
            : SshKeyService.instance.algorithmOfPublicKeyLine(publicKeyLine),
        publicKey: publicKeyLine.isEmpty ? null : publicKeyLine,
        fingerprint: publicKeyLine.isEmpty
            ? null
            : SshKeyService.instance.fingerprintOfPublicKeyLine(publicKeyLine),
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      if (_isEditing) {
        await repo.update(identity);
      } else {
        await repo.insert(identity);
      }

      await ref.read(auditRepositoryProvider).log(
            action: _isEditing ? 'update' : 'create',
            entityType: 'identity',
            entityId: identity.id,
            details: identity.name,
          );

      ref.invalidate(identitiesProvider);
      ref.invalidate(identityUsageProvider);
      if (widget.identityId != null) {
        ref.invalidate(identityDetailProvider(widget.identityId!));
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) _showMessage('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit credential' : 'New credential'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  SegmentedButton<IdentityType>(
                    segments: const [
                      ButtonSegment(
                        value: IdentityType.sshKey,
                        icon: Icon(Icons.vpn_key_outlined, size: 18),
                        label: Text('SSH key'),
                      ),
                      ButtonSegment(
                        value: IdentityType.password,
                        icon: Icon(Icons.password_outlined, size: 18),
                        label: Text('Password'),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selection) =>
                        setState(() => _type = selection.first),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Production deploy key',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  if (_type == IdentityType.password)
                    _buildPasswordFields(colors)
                  else
                    _buildKeyFields(colors),
                ],
              ),
            ),
    );
  }

  Widget _buildPasswordFields(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _passwordController,
          obscureText: _obscureSecret,
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Generate',
                  icon: const Icon(Icons.casino_outlined, size: 20),
                  onPressed: () {
                    _passwordController.text =
                        ref.read(encryptionServiceProvider).generatePassword();
                    setState(() => _obscureSecret = false);
                  },
                ),
                IconButton(
                  icon: Icon(
                    _obscureSecret ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                ),
              ],
            ),
          ),
          validator: (v) =>
              (v == null || v.isEmpty) && _type == IdentityType.password ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        Text(
          'Stored AES-256-GCM encrypted under your master password.',
          style: context.text.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  Widget _buildKeyFields(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_KeySource>(
          segments: const [
            ButtonSegment(value: _KeySource.paste, label: Text('Paste')),
            ButtonSegment(value: _KeySource.file, label: Text('File')),
            ButtonSegment(value: _KeySource.generate, label: Text('Generate')),
          ],
          selected: {_keySource},
          onSelectionChanged: (selection) => setState(() => _keySource = selection.first),
        ),
        const SizedBox(height: 16),

        if (_keySource == _KeySource.file) ...[
          OutlinedButton.icon(
            onPressed: _pickKeyFile,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Choose private key file'),
          ),
          const SizedBox(height: 16),
        ],

        if (_keySource == _KeySource.generate) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Generate an RSA key pair', style: context.text.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'The private key never leaves this device. Ed25519 keys can '
                    'be imported but not generated here.',
                    style: context.text.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 2048, label: Text('2048')),
                      ButtonSegment(value: 3072, label: Text('3072')),
                      ButtonSegment(value: 4096, label: Text('4096')),
                    ],
                    selected: {_generateBits},
                    onSelectionChanged: (s) => setState(() => _generateBits = s.first),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _generating ? null : _generateKey,
                    icon: _generating
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(_generating ? 'Generating…' : 'Generate'),
                  ),
                  if (_generating) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Larger keys take noticeably longer — 4096 bits can run '
                      'for a minute or more on a phone.',
                      style: context.text.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        TextFormField(
          controller: _privateKeyController,
          decoration: const InputDecoration(
            labelText: 'Private key',
            hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
            alignLabelWithHint: true,
          ),
          style: AppTypography.monoStyle(size: 11, color: context.scheme.onSurface),
          maxLines: 8,
          minLines: 4,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => _validateKey(),
          validator: (v) =>
              (v == null || v.trim().isEmpty) && _type == IdentityType.sshKey ? 'Required' : null,
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _passphraseController,
          obscureText: _obscureSecret,
          decoration: InputDecoration(
            labelText: 'Key passphrase (if any)',
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSecret ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
            ),
          ),
          onChanged: (_) => _validateKey(),
        ),

        if (_keyStatus != null) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _keyStatusIsError ? Icons.error_outline : Icons.check_circle_outline,
                size: 16,
                color: _keyStatusIsError ? colors.danger : colors.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _keyStatus!,
                  style: context.text.bodySmall?.copyWith(
                    color: _keyStatusIsError ? colors.danger : colors.success,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),
        TextFormField(
          controller: _publicKeyController,
          decoration: InputDecoration(
            labelText: 'Public key (optional)',
            hintText: 'ssh-ed25519 AAAA… user@host',
            helperText: 'Paste the matching .pub line to record a fingerprint '
                'and enable one-tap install on a host.',
            helperMaxLines: 3,
            alignLabelWithHint: true,
            suffixIcon: IconButton(
              tooltip: 'Paste from clipboard',
              icon: const Icon(Icons.content_paste, size: 20),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) _publicKeyController.text = data!.text!.trim();
              },
            ),
          ),
          style: AppTypography.monoStyle(size: 11, color: context.scheme.onSurface),
          maxLines: 3,
          minLines: 1,
          autocorrect: false,
          enableSuggestions: false,
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _commentController,
          decoration: const InputDecoration(labelText: 'Comment (optional)'),
        ),
      ],
    );
  }
}
