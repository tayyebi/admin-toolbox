import 'package:flutter/material.dart';

import '../../data/transport/ssh_client.dart';
import '../routes.dart';
import 'host_key_dialog.dart';

/// Two very different situations share this dialog, and they are styled
/// differently on purpose. An unknown key is routine — you see it the first
/// time you connect anywhere. A *changed* key means the server is not the one
/// you pinned, which is either a rebuild or an interception, and the dialog
/// should not let that slide past as another "OK".
Future<bool> showHostKeyPrompt(HostKeyPrompt prompt) async {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return false;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => HostKeyDialog(prompt: prompt),
  );
  return accepted ?? false;
}
