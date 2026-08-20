import 'package:sqflite/sqflite.dart';

import 'indexes.dart';
import 'inventory_tables.dart';
import 'monitoring_tables.dart';
import 'operations_tables.dart';
import 'system_tables.dart';
import 'vault_tables.dart';

export 'indexes.dart';
export 'inventory_tables.dart';
export 'monitoring_tables.dart';
export 'operations_tables.dart';
export 'system_tables.dart';
export 'vault_tables.dart';

/// Every table, in creation order.
const allTables = <String>[
  ...inventoryTables,
  ...vaultTables,
  ...monitoringTables,
  ...operationsTables,
  ...systemTables,
];

Future<void> createSchema(Database db) async {
  for (final statement in allTables) {
    await db.execute(statement);
  }
  await createIndexes(db);
}

Future<void> createIndexes(Database db) async {
  for (final statement in indexStatements) {
    await db.execute(statement);
  }
}
