import 'dart:isolate';

import 'package:drift/drift.dart';

import '../app_info.dart';
import '../database/app_database.dart';
import '../models/ledger_types.dart';
import 'backup_validator.dart';
import 'restore_plan.dart';

enum RestoreOutcome { restored, cancelled }

class BackupService {
  BackupService(this._database);
  final AppDatabase _database;

  Future<Uint8List> exportBytes() =>
      _database.exclusiveLedgerOperation(() async {
        final snapshot = await _snapshot();
        return Isolate.run(snapshot.encode);
      });

  Future<ValidatedBackup> _snapshot() => _database.transaction(() async {
    const tableNames = {
      'categories': 'categories',
      'currencies': 'currencies',
      'transactions': 'transactions',
      'settings': 'app_settings',
    };
    const primaryKeys = {
      'categories': 'id',
      'currencies': 'code',
      'transactions': 'id',
      'settings': 'key',
    };
    var payload = 0;
    final tables = <String, List<Map<String, Object?>>>{};
    // Bound raw payload before fetching full rows. This SUM counts bytes, never money.
    for (final table in tableNames.entries) {
      final count = await _database
          .customSelect('SELECT count(*) AS n FROM ${table.value}')
          .getSingle();
      if (count.read<int>('n') > backupMaxRowsPerTable) {
        throw const LedgerException(
          'The ledger exceeds the supported backup row limit.',
        );
      }
      final sizes = backupColumns[table.key]!
          .map((column) => 'COALESCE(length(CAST($column AS BLOB)), 0)')
          .join(' + ');
      final size = await _database
          .customSelect(
            'SELECT COALESCE(SUM($sizes), 0) AS bytes FROM ${table.value}',
          )
          .getSingle();
      payload += size.read<int>('bytes');
      if (payload > backupMaxBytes) {
        throw const LedgerException(
          'The ledger exceeds the 25 MiB backup limit.',
        );
      }
    }
    for (final table in tableNames.entries) {
      final rows = await _database
          .customSelect(
            'SELECT * FROM ${table.value} ORDER BY ${primaryKeys[table.key]}',
          )
          .get();
      tables[table.key] = rows
          .map((row) => Map<String, Object?>.from(row.data))
          .toList();
    }
    final exportedAt = DateTime.now().toUtc();
    return BackupValidator.snapshotInBackground(
      tables: tables,
      appVersion: appVersion,
      exportedAtUtc: exportedAt,
    );
  });

  /// The exclusive gate spans the last committed snapshot, native safety-save
  /// callback, and replacement. Cancellation/failure never starts replacement.
  Future<RestoreOutcome> restore(
    ValidatedBackup backup, {
    Future<bool> Function(Uint8List bytes)? saveSafetyBackup,
  }) => _database.exclusiveLedgerOperation(() async {
    if (saveSafetyBackup != null) {
      final snapshot = await _snapshot();
      final bytes = await Isolate.run(snapshot.encode);
      if (!await saveSafetyBackup(bytes)) return RestoreOutcome.cancelled;
    }
    await _database.transaction(() async {
      final iterator = replacementStatements(backup).iterator;
      var more = true;
      while (more) {
        final chunk = <BackupSqlWrite>[];
        while (chunk.length < 500 && (more = iterator.moveNext())) {
          chunk.add(iterator.current);
        }
        if (chunk.isNotEmpty) {
          await _database.batch((batch) {
            for (final statement in chunk) {
              batch.customStatement(statement.sql, statement.arguments);
            }
          });
        }
      }
      if ((await _database.customSelect('PRAGMA foreign_key_check').get())
          .isNotEmpty) {
        throw const LedgerException(
          'The restored ledger failed its reference integrity check.',
        );
      }
    });
    _database.markLedgerRestored();
    // Publish only after commit. Failed restores do not notify partial data.
    _database.notifyUpdates({
      for (final table in [
        'categories',
        'currencies',
        'transactions',
        'app_settings',
      ])
        TableUpdate(table),
    });
    return RestoreOutcome.restored;
  });
}
