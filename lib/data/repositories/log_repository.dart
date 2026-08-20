import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';

export 'log_queries.dart';

/// The persisted application log.
///
/// Fed from `core/utils/logger.dart` via its `logSink` callback rather than
/// imported by it directly, so the low-level logger stays free of any
/// dependency on the data layer. Storing a log entry must never throw or log
/// through `logInfo`/`logWarning`/`logError` itself — that would feed back
/// into the same sink and risk recursion — so failures here are swallowed
/// silently.
class LogRepository {
  final _uuid = const Uuid();
  int _writes = 0;

  static const _maxEntries = 5000;

  Future<void> add(String level, String message) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.insert('app_log', {
        'id': _uuid.v4(),
        'level': level,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Trimming on every write would cost a query per log line; every 50th
      // is frequent enough to keep the table bounded without that overhead.
      if (++_writes % 50 == 0) await _trim(db);
    } catch (_) {
      // The log store failing must never crash the logger recording it.
    }
  }

  Future<void> _trim(Database db) async {
    await db.delete(
      'app_log',
      where: 'id NOT IN (SELECT id FROM app_log ORDER BY timestamp DESC LIMIT ?)',
      whereArgs: [_maxEntries],
    );
  }
}
