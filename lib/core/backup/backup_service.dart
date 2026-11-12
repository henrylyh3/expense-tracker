import 'dart:convert';
import 'dart:isolate';

import 'package:drift/drift.dart';

import '../app_info.dart';
import '../database/app_database.dart';
import '../models/ledger_types.dart';
import 'backup_validator.dart';
import 'restore_plan.dart';
import 'trip_import.dart';

enum RestoreOutcome { restored, cancelled }

class BackupService {
  BackupService(this._database);
  final AppDatabase _database;

  Future<Uint8List> exportBytes({Set<String>? tripIds}) =>
      _database.exclusiveLedgerOperation(() async {
        final snapshot = await _snapshot(tripIds: tripIds);
        return Isolate.run(snapshot.encode);
      });

  Future<ValidatedBackup> _snapshot({
    Set<String>? tripIds,
  }) => _database.transaction(() async {
    const tableNames = {
      'categories': 'categories',
      'currencies': 'currencies',
      'transactions': 'transactions',
      'trips': 'trips',
      'trip_rates': 'trip_rates',
      'currency_rates': 'currency_rates',
      'settings': 'app_settings',
    };
    const primaryKeys = {
      'categories': 'id',
      'currencies': 'code',
      'transactions': 'id',
      'trips': 'id',
      'trip_rates': 'trip_id, currency_code',
      'currency_rates': 'id',
      'settings': 'key',
    };
    var payload = 0;
    final tables = <String, List<Map<String, Object?>>>{};
    final scopes = tripIds == null
        ? const <String, String>{}
        : {
            'trips': 'id IN selected',
            'transactions': 'trip_id IN selected',
            'trip_rates': 'trip_id IN selected',
            'categories':
                'id IN (SELECT category_id FROM transactions WHERE trip_id IN selected)',
            'currencies':
                "code = 'MYR' OR code IN (SELECT currency_code FROM transactions WHERE trip_id IN selected UNION SELECT currency_code FROM trip_rates WHERE trip_id IN selected)",
            'currency_rates':
                'id IN (SELECT rate_id FROM trip_rates WHERE trip_id IN selected)',
            'settings': "key = 'theme_mode'",
          };
    Selectable<QueryRow> select(
      String table,
      String projection, {
      String order = '',
    }) {
      final filter = scopes[table];
      final usesSelection = filter?.contains('IN selected') ?? false;
      return _database.customSelect(
        '${usesSelection ? 'WITH selected AS (SELECT value FROM json_each(?)) ' : ''}'
        'SELECT $projection FROM ${tableNames[table]}'
        '${filter == null ? '' : ' WHERE $filter'}$order',
        variables: [
          if (usesSelection) Variable.withString(jsonEncode(tripIds!.toList())),
        ],
      );
    }

    // Bound raw payload before fetching full rows. This SUM counts bytes, never money.
    for (final table in tableNames.entries) {
      final count = await select(table.key, 'count(*) AS n').getSingle();
      if (count.read<int>('n') > backupMaxRowsPerTable) {
        throw const LedgerException(
          'The ledger exceeds the supported backup row limit.',
        );
      }
      final sizes = backupColumns[table.key]!
          .map((column) => 'COALESCE(length(CAST($column AS BLOB)), 0)')
          .join(' + ');
      final size = await select(
        table.key,
        'COALESCE(SUM($sizes), 0) AS bytes',
      ).getSingle();
      payload += size.read<int>('bytes');
      if (payload > backupMaxBytes) {
        throw const LedgerException(
          'The ledger exceeds the 25 MiB backup limit.',
        );
      }
    }
    for (final table in tableNames.entries) {
      final rows = await select(
        table.key,
        '*',
        order: ' ORDER BY ${primaryKeys[table.key]}',
      ).get();
      tables[table.key] = rows
          .map((row) => Map<String, Object?>.from(row.data))
          .toList();
    }
    if (tripIds != null &&
        (tripIds.isEmpty || tables['trips']!.length != tripIds.length)) {
      throw const LedgerException('Choose existing trips to export.');
    }
    final exportedAt = DateTime.now().toUtc();
    return BackupValidator.snapshotInBackground(
      tables: tables,
      appVersion: appVersion,
      exportedAtUtc: exportedAt,
      isTripExport: tripIds != null,
    );
  });

  /// The exclusive gate spans the last committed snapshot, native safety-save
  /// callback, and replacement. Cancellation/failure never starts replacement.
  Future<RestoreOutcome> restore(
    ValidatedBackup backup, {
    Future<bool> Function(Uint8List bytes)? saveSafetyBackup,
  }) => _database.exclusiveLedgerOperation(() async {
    if (backup.isTripExport) {
      throw const LedgerException(
        'A selected-trip export must be imported into an existing ledger.',
      );
    }
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
        'trips',
        'trip_rates',
        'currency_rates',
        'shared_sessions',
        'shared_pending',
        'shared_receipts',
        'app_settings',
      ])
        TableUpdate(table),
    });
    return RestoreOutcome.restored;
  });

  Future<void> importTrips(
    ValidatedBackup backup,
    Map<String, String?> destinations,
  ) async {
    await _database.writeTransaction(
      () => importBackupTrips(_database, backup, destinations),
    );
    _database.notifyUpdates({
      for (final table in [
        'trips',
        'categories',
        'currencies',
        'currency_rates',
        'trip_rates',
        'transactions',
      ])
        TableUpdate(table),
    });
  }
}
