import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xterm/xterm.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/command.dart';
import '../../../data/transport/connection_manager.dart';
import '../../../data/transport/ssh_client.dart';
import '../../../data/transport/transport.dart';
import '../../../providers/providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/host_key_dialog.dart';

/// A real interactive shell.
///
/// The previous screen displayed fixed placeholder text and a text field whose
/// send button did nothing. This attaches `xterm` to a PTY over SSH, so
/// full-screen programs, colour and control sequences all behave.
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key, required this.hostId});

  final String hostId;

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  late final Terminal _terminal;
  final _terminalController = TerminalController();

  ShellSession? _shell;
  StreamSubscription<Uint8List>? _outputSubscription;

  bool _connecting = true;
  String? _error;
  bool _sessionEnded = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 5000);
    _connect();
  }

  @override
  void dispose() {
    unawaited(_teardown());
    _terminalController.dispose();
    super.dispose();
  }

  Future<void> _teardown() async {
    await _outputSubscription?.cancel();
    _outputSubscription = null;
    await _shell?.close();
    _shell = null;

    final host = ref.read(hostDetailProvider(widget.hostId)).valueOrNull;
    if (host != null) ref.read(connectionManagerProvider).release(host);

    await WakelockPlus.disable();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
      _sessionEnded = false;
    });

    try {
      final host = await ref.read(hostRepositoryProvider).getById(widget.hostId);
      if (host == null) throw StateError('Host not found');

      final manager = ref.read(connectionManagerProvider)..onHostKeyPrompt = showHostKeyPrompt;
      final session = await manager.acquire(host);

      final shell = await session.openShell(
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
      );
      _shell = shell;

      // Remote → screen.
      _outputSubscription = shell.output.listen(
        (data) => _terminal.write(utf8.decode(data, allowMalformed: true)),
        onError: (Object e) => logWarning('Terminal stream error: $e'),
        onDone: () {
          if (mounted) setState(() => _sessionEnded = true);
        },
      );

      // Keyboard → remote.
      _terminal.onOutput = (data) => shell.write(Uint8List.fromList(utf8.encode(data)));

      // Rotation and keyboard changes must reach the remote PTY, or
      // full-screen programs keep drawing at the old size.
      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        shell.resize(width, height, pixelWidth: pixelWidth, pixelHeight: pixelHeight);
      };

      unawaited(shell.done.whenComplete(() {
        if (mounted) setState(() => _sessionEnded = true);
      }));

      // An open session that sleeps mid-command is worse than useless.
      await WakelockPlus.enable();

      await ref.read(auditRepositoryProvider).log(
            action: 'terminal_open',
            entityType: 'host',
            entityId: host.id,
            hostId: host.id,
            details: host.endpoint,
          );

      if (mounted) setState(() => _connecting = false);
    } on HostKeyRejectedException catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = e.toString();
        });
      }
    } on MissingIdentityException catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = e.toString();
        });
      }
    } catch (e, stack) {
      logError('Could not open terminal', e, stack);
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _reconnect() async {
    await _teardown();
    _terminal.write('\r\n\x1b[33m— reconnecting —\x1b[0m\r\n');
    await _connect();
  }

  void _copySelection() {
    final selection = _terminalController.selection;
    if (selection == null) {
      _notify('Nothing selected');
      return;
    }
    final text = _terminal.buffer.getText(selection);
    _terminalController.clearSelection();
    Clipboard.setData(ClipboardData(text: text));
    _notify('Copied');
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _terminal.paste(text);
  }

  Future<void> _showCommandLibrary() async {
    final commands = await ref.read(commandRepositoryProvider).getAll();
    if (!mounted) return;

    if (commands.isEmpty) {
      _notify('No saved commands yet');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scrollController) => ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          itemCount: commands.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text('Command library', style: context.text.titleLarge),
              );
            }
            final command = commands[index - 1];
            return ListTile(
              title: Text(command.name),
              subtitle: Text(
                command.command,
                style: AppTypography.monoSmall(context.colors.textMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _insertCommand(command);
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _insertCommand(Command command) async {
    var text = command.command;
    final placeholders = Command.placeholdersIn(text);

    if (placeholders.isNotEmpty) {
      final values = await _promptForVariables(placeholders);
      if (values == null) return;
      text = command.interpolate(values);
    }

    // Inserted, not executed — the user still presses Enter, which keeps a
    // destructive command from running on a mistap.
    _terminal.paste(text);
  }

  Future<Map<String, String>?> _promptForVariables(List<String> names) async {
    final controllers = {for (final name in names) name: TextEditingController()};

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fill in variables'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final name in names) ...[
                TextField(
                  controller: controllers[name],
                  decoration: InputDecoration(labelText: name),
                  autofocus: name == names.first,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              {for (final entry in controllers.entries) entry.key: entry.value.text},
            ),
            child: const Text('Insert'),
          ),
        ],
      ),
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hostAsync = ref.watch(hostDetailProvider(widget.hostId));
    final fontSize = ref.watch(settingsProvider.select((s) => s.terminalFontSize));
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.terminalBackground,
      appBar: AppBar(
        title: Text(hostAsync.valueOrNull?.name ?? 'Terminal'),
        actions: [
          IconButton(
            tooltip: 'Copy selection',
            icon: const Icon(Icons.content_copy, size: 20),
            onPressed: _copySelection,
          ),
          IconButton(
            tooltip: 'Paste',
            icon: const Icon(Icons.content_paste, size: 20),
            onPressed: _paste,
          ),
          IconButton(
            tooltip: 'Command library',
            icon: const Icon(Icons.playlist_add, size: 20),
            onPressed: _showCommandLibrary,
          ),
          IconButton(
            tooltip: 'Reconnect',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _reconnect,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_sessionEnded)
              _Banner(
                message: 'Session closed by the remote host.',
                actionLabel: 'Reconnect',
                onAction: _reconnect,
              ),
            Expanded(child: _buildTerminalArea(fontSize)),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalArea(double fontSize) {
    if (_connecting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(height: 16),
            Text('Connecting…'),
          ],
        ),
      );
    }

    if (_error != null) {
      return ErrorView(
        error: _error!,
        title: 'Could not open a shell',
        onRetry: _reconnect,
      );
    }

    return TerminalView(
      _terminal,
      controller: _terminalController,
      autofocus: true,
      backgroundOpacity: 1,
      textStyle: TerminalStyle(
        fontSize: fontSize,
        fontFamily: AppTypography.mono,
      ),
      padding: const EdgeInsets.all(8),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.colors.warning.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: context.colors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: context.text.bodySmall?.copyWith(color: context.colors.terminalForeground),
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
