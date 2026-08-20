/// The transport contract every screen and engine talks to.
///
/// Kept as a barrel so callers import one path, and so the implementation
/// underneath can be swapped without touching a single import site.
library;

export 'command_result.dart';
export 'file_entry.dart';
export 'host_key_rejected_exception.dart';
export 'shell_session.dart';
export 'transport_connection_config.dart';
export 'transport_session.dart';
export 'transport_type.dart';
