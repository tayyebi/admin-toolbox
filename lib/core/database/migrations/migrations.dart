import 'package:sqflite/sqflite.dart';

import '../../utils/logger.dart';
import 'v2.dart';
import 'v3.dart';
import 'v4.dart';
import 'v5.dart';
import 'v6.dart';

export 'add_column.dart';

/// Every upgrade step, keyed by the version it produces.
///
/// Each runs when the database is older than its key, in ascending order, so a
/// device three versions behind walks the same path as one that is only one
/// behind. Adding a version means adding a file and one entry here.
const _steps = <int, Future<void> Function(Database)>{
  2: migrateToV2,
  3: migrateToV3,
  4: migrateToV4,
  5: migrateToV5,
  6: migrateToV6,
};

Future<void> runMigrations(Database db, int oldVersion, int newVersion) async {
  logInfo('Migrating database from v$oldVersion to v$newVersion');

  final versions = _steps.keys.toList()..sort();
  for (final version in versions) {
    if (oldVersion < version) await _steps[version]!(db);
  }
}
