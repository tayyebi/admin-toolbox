import 'package:sqflite/sqflite.dart';

import 'add_column.dart';

/// Adds per-host monitoring pause, so one noisy or intentionally-down host
/// can be skipped by the sweep without deleting it from the inventory.
Future<void> migrateToV3(Database db) =>
    addColumnIfMissing(db, 'hosts', 'monitoring_paused', 'INTEGER NOT NULL DEFAULT 0');
