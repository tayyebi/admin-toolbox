import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';

class TerminalScreen extends ConsumerWidget {
  final String hostId;

  const TerminalScreen({super.key, required this.hostId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostAsync = ref.watch(hostDetailProvider(hostId));

    return Scaffold(
      appBar: AppBar(
        title: hostAsync.when(
          data: (host) => Text('${host?.name ?? 'Host'} - Terminal'),
          loading: () => const Text('Terminal'),
          error: (_, __) => const Text('Terminal'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.content_copy), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.history), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF0D1117),
              child: const SingleChildScrollView(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SSH Terminal\nTerminal connection will be established here.\n\nType commands to interact with the remote host.\n\nConnected to host...',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppTheme.bgCard,
              border: Border(top: BorderSide(color: AppTheme.borderDefault)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  const Text('admin@host:~\$ ', style: TextStyle(fontFamily: 'JetBrainsMono', color: AppTheme.successGreen, fontSize: 13)),
                  const Expanded(
                    child: TextField(
                      style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13, color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Enter command...',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppTheme.primaryBlue, size: 20),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
