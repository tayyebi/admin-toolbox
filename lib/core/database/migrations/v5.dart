import 'package:sqflite/sqflite.dart';

import 'add_column.dart';

/// Adds a per-host connect timeout, so slow or high-latency hosts do not have
/// to share one global value with everything else.
Future<void> migrateToV5(Database db) => addColumnIfMissing(
      db,
      'hosts',
      'connect_timeout_seconds',
      'INTEGER NOT NULL DEFAULT 30',
    );
