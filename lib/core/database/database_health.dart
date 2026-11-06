import 'package:drift/drift.dart';

/// Read-only startup checks, run in one consistent snapshot after opening.
/// Never repairs, reseeds, deletes or replaces an existing ledger.
Future<void> verifyLedgerHealth(
  GeneratedDatabase database,
) => database.transaction(() async {
  final foreignKeys = await database
      .customSelect('PRAGMA foreign_keys')
      .getSingle();
  if (foreignKeys.read<int>('foreign_keys') != 1) {
    throw StateError('Database foreign-key enforcement is unavailable.');
  }

  final objects = await database
      .customSelect('SELECT name, type FROM sqlite_schema')
      .get();
  final existing = {
    for (final row in objects)
      (row.read<String>('name'), row.read<String>('type')),
  };
  for (final entity in database.allSchemaEntities) {
    final type = switch (entity) {
      TableInfo<Table, Object?>() => 'table',
      Index() => 'index',
      Trigger() => 'trigger',
      ViewInfo<HasResultSet, Object?>() => 'view',
      _ => null, // For example, seed queries are not schema objects.
    };
    if (type != null && !existing.contains((entity.entityName, type))) {
      throw StateError('A required ledger schema object is missing.');
    }
  }
  for (final table in database.allTables) {
    final rows = await database
        .customSelect(
          'SELECT name FROM pragma_table_info(?)',
          variables: [Variable.withString(table.actualTableName)],
        )
        .get();
    final actual = {for (final row in rows) row.read<String>('name')};
    final expected = {for (final column in table.$columns) column.name};
    if (actual.length != expected.length || !actual.containsAll(expected)) {
      throw StateError('Ledger columns do not match the supported schema.');
    }
  }

  // Bound error materialization. SQLite still scans the ledger, on Drift's
  // background executor, to check structure and CHECK/NOT NULL constraints.
  final check = await database
      .customSelect('PRAGMA quick_check(1)')
      .getSingle();
  if (check.data.values.singleOrNull != 'ok') {
    throw StateError('Ledger storage failed its integrity check.');
  }
  final references = await database
      .customSelect('SELECT 1 FROM pragma_foreign_key_check LIMIT 1')
      .get();
  if (references.isNotEmpty) {
    throw StateError('Ledger storage contains an invalid reference.');
  }
  final myr = await database
      .customSelect(
        "SELECT decimal_places, rate_to_myr, is_active FROM currencies WHERE code = 'MYR'",
      )
      .getSingleOrNull();
  if (myr == null ||
      myr.read<int>('decimal_places') != 2 ||
      myr.read<String>('rate_to_myr') != '1' ||
      myr.read<int>('is_active') != 1) {
    throw StateError('The fixed base currency is missing or invalid.');
  }
  final trip = await database.customSelect(
    """SELECT 1 FROM trips WHERE id = COALESCE(
      (SELECT value FROM app_settings WHERE key = 'active_trip'), 'personal')""",
  ).getSingleOrNull();
  if (trip == null) {
    throw StateError('The default trip is missing.');
  }
  final theme = await database
      .customSelect("SELECT value FROM app_settings WHERE key = 'theme_mode'")
      .getSingleOrNull();
  if (theme == null ||
      !{'system', 'light', 'dark'}.contains(theme.read<String>('value'))) {
    throw StateError('The appearance setting is missing or invalid.');
  }
});
