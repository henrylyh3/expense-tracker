import 'backup_validator.dart';

class BackupSqlWrite {
  BackupSqlWrite(this.sql, Iterable<Object?> arguments)
    : arguments = List.unmodifiable(arguments);
  final String sql;
  final List<Object?> arguments;
}

/// A lazy, parameterized plan. Never uses REPLACE, drops tables, disables FKs,
/// or deletes MYR. The service runs every statement in one SQLite transaction.
Iterable<BackupSqlWrite> replacementStatements(ValidatedBackup backup) sync* {
  yield BackupSqlWrite('DELETE FROM transactions', const []);
  yield BackupSqlWrite('DELETE FROM trip_rates', const []);
  yield BackupSqlWrite('DELETE FROM trips', const []);
  yield BackupSqlWrite('DELETE FROM categories', const []);
  yield BackupSqlWrite("DELETE FROM currencies WHERE code <> 'MYR'", const []);
  yield BackupSqlWrite('DELETE FROM app_settings', const []);
  const tableNames = {
    'currencies': 'currencies',
    'categories': 'categories',
    'settings': 'app_settings',
    'trips': 'trips',
    'trip_rates': 'trip_rates',
    'transactions': 'transactions',
  };
  for (final table in tableNames.entries) {
    final columns = backupColumns[table.key]!;
    final insert =
        'INSERT INTO ${table.value} (${columns.join(', ')}) VALUES (${List.filled(columns.length, '?').join(', ')})';
    for (final row in backup.tables[table.key]!) {
      final upsert = table.key == 'currencies' && row['code'] == 'MYR'
          ? ' ON CONFLICT(code) DO UPDATE SET ${columns.where((name) => name != 'code').map((name) => '$name = excluded.$name').join(', ')}'
          : '';
      yield BackupSqlWrite(
        '$insert$upsert',
        columns.map((column) => row[column]),
      );
    }
  }
}
