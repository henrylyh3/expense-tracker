import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/ledger_types.dart';
import 'backup_validator.dart';
import 'restore_plan.dart';

/// Runs inside the ledger write transaction. A null destination explicitly
/// requests a new profile for a name that already exists.
Future<void> importBackupTrips(
  AppDatabase db,
  ValidatedBackup backup,
  Map<String, String?> destinations,
) async {
  Future<List<Map<String, Object?>>> read(String table) async =>
      (await db.customSelect('SELECT * FROM $table').get())
          .map((row) => row.data)
          .toList();

  final incoming = backup.tables;
  final localTrips = await read('trips');
  final localCategories = await read('categories');
  final localCurrencies = await read('currencies');
  final localRates = await read('currency_rates');
  const uuid = Uuid();
  final newTrips = <Map<String, Object?>>[];
  final tripIds = <String, String>{};
  final tripsByName = <String, Set<String>>{};
  for (final trip in localTrips) {
    (tripsByName[(trip['name'] as String).toLowerCase()] ??= {}).add(
      trip['id'] as String,
    );
  }
  final tripNames = tripsByName.keys.toSet();
  for (final trip in incoming['trips']!) {
    final id = trip['id'] as String;
    final name = trip['name'] as String;
    final matches = tripsByName[name.toLowerCase()] ?? const <String>{};
    final target = destinations[id];
    if ((matches.isNotEmpty && !destinations.containsKey(id)) ||
        (target != null && !matches.contains(target))) {
      throw const LedgerException(
        'Trip names changed. Review the import choices again.',
      );
    }
    if (target != null) {
      tripIds[id] = target;
    } else {
      final newId = uuid.v4();
      tripIds[id] = newId;
      newTrips.add({'id': newId, 'name': _availableName(name, tripNames)});
    }
  }

  final sourceTransactions = incoming['transactions']!;
  String copyId(String id, String trip) =>
      uuid.v5(Namespace.url.value, 'expense-tracker:trip-import:$trip:$id');
  final existingTransactions = {
    for (final row
        in await db
            .customSelect(
              'SELECT lower(id) AS id, trip_id FROM transactions WHERE lower(id) IN (SELECT value FROM json_each(?))',
              variables: [
                Variable.withString(
                  jsonEncode([
                    for (final tx in sourceTransactions) ...[
                      (tx['id'] as String).toLowerCase(),
                      copyId(
                        (tx['id'] as String).toLowerCase(),
                        tripIds[tx['trip_id']]!,
                      ),
                    ],
                  ]),
                ),
              ],
            )
            .get())
      row.read<String>('id'): row.read<String>('trip_id'),
  };

  final categoryIds = <String, String>{};
  final rateIds = <String, String>{};
  final currencyCodes = localCurrencies.map((row) => row['code']).toSet();
  final sourcePrecision = {
    for (final row in incoming['currencies']!)
      row['code']: row['decimal_places'],
  };
  final categoriesByName = {
    for (final row in localCategories)
      (row['type'], (row['name'] as String).toLowerCase()): row['id'] as String,
  };
  final usedCategoryIds = localCategories.map((row) => row['id']).toSet();
  final ratesById = {for (final row in localRates) row['id']: row};
  final ratesByNameAndValue = {
    for (final row in localRates)
      (
        row['currency_code'],
        (row['name'] as String).toLowerCase(),
        row['rate_to_myr'],
      ): row['id'] as String,
  };
  final rateNames = localRates
      .map((row) => (row['name'] as String).toLowerCase())
      .toSet();

  Iterable<BackupSqlWrite> writes() sync* {
    for (final row in newTrips) {
      yield _insert('trips', row);
    }
    for (final row in incoming['currencies']!) {
      if (currencyCodes.add(row['code'])) yield _insert('currencies', row);
    }
    for (final row in incoming['categories']!) {
      final id = row['id'] as String;
      final key = (row['type'], (row['name'] as String).toLowerCase());
      final existing = categoriesByName[key];
      if (existing != null) {
        categoryIds[id] = existing;
      } else {
        final newId = usedCategoryIds.contains(id) ? uuid.v4() : id;
        usedCategoryIds.add(newId);
        categoriesByName[key] = newId;
        categoryIds[id] = newId;
        yield _insert('categories', {...row, 'id': newId});
      }
    }
    for (final row in incoming['currency_rates']!) {
      final id = row['id'] as String;
      final name = row['name'] as String;
      final key = (
        row['currency_code'],
        name.toLowerCase(),
        row['rate_to_myr'],
      );
      final existing = ratesByNameAndValue[key];
      if (existing != null) {
        rateIds[id] = existing;
      } else {
        final alias = uuid.v5(
          Namespace.url.value,
          'expense-tracker:imported-rate:${jsonEncode([id, row['currency_code'], name, row['rate_to_myr']])}',
        );
        final imported = ratesById[alias];
        if (imported != null &&
            imported['currency_code'] == row['currency_code'] &&
            imported['rate_to_myr'] == row['rate_to_myr']) {
          rateIds[id] = alias;
          continue;
        }
        final needsAlias =
            ratesById.containsKey(id) || rateNames.contains(name.toLowerCase());
        final newId = !needsAlias
            ? id
            : imported == null
            ? alias
            : uuid.v4();
        ratesByNameAndValue[key] = newId;
        rateIds[id] = newId;
        final newRow = {
          ...row,
          'id': newId,
          'name': _availableName(name, rateNames),
        };
        ratesById[newId] = newRow;
        yield _insert('currency_rates', newRow);
      }
    }
    for (final row in incoming['trip_rates']!) {
      yield _insert('trip_rates', {
        ...row,
        'trip_id': tripIds[row['trip_id']],
        'rate_id': rateIds[row['rate_id']],
      }, onConflict: ' ON CONFLICT(trip_id, currency_code) DO NOTHING');
    }
    for (final row in sourceTransactions) {
      final trip = tripIds[row['trip_id']]!;
      final sourceId = (row['id'] as String).toLowerCase();
      final copy = copyId(sourceId, trip);
      if (existingTransactions[sourceId] == trip ||
          existingTransactions[copy] == trip) {
        continue;
      }
      final id = existingTransactions.containsKey(sourceId) ? copy : sourceId;
      existingTransactions[id] = trip;
      yield _insert('transactions', {
        ...row,
        'id': id,
        'trip_id': trip,
        'category_id': categoryIds[row['category_id']],
        'amount_decimal_places':
            row['amount_decimal_places'] ??
            sourcePrecision[row['currency_code']],
      });
    }
  }

  final pending = writes().iterator;
  var more = true;
  while (more) {
    final chunk = <BackupSqlWrite>[];
    while (chunk.length < 500 && (more = pending.moveNext())) {
      chunk.add(pending.current);
    }
    if (chunk.isNotEmpty) {
      await db.batch((batch) {
        for (final statement in chunk) {
          batch.customStatement(statement.sql, statement.arguments);
        }
      });
    }
  }
}

String _availableName(String name, Set<String> used) {
  if (used.add(name.toLowerCase())) return name;
  for (var index = 1; ; index++) {
    final suffix = ' ($index)';
    final prefix = String.fromCharCodes(
      name.runes.take(80 - suffix.length),
    ).trimRight();
    final candidate = '$prefix$suffix';
    if (used.add(candidate.toLowerCase())) return candidate;
  }
}

BackupSqlWrite _insert(
  String table,
  Map<String, Object?> row, {
  String onConflict = '',
}) {
  final columns = backupColumns[table]!;
  return BackupSqlWrite(
    'INSERT INTO $table (${columns.join(', ')}) VALUES (${List.filled(columns.length, '?').join(', ')})$onConflict',
    columns.map((column) => row[column]),
  );
}
