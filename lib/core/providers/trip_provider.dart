import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/ledger_types.dart';
import '../money/exchange_rate.dart';
import '../validation/input_validation.dart';
import 'database_providers.dart';

typedef TripCurrencyRate = ({String rate, String? name});

const personalTripId = 'personal';

final tripsProvider = StreamProvider<List<({String id, String name})>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT id, name FROM trips ORDER BY name COLLATE NOCASE, id',
        readsFrom: {db.trips},
      )
      .watch()
      .map(
        (rows) => [
          for (final row in rows)
            (id: row.read<String>('id'), name: row.read<String>('name')),
        ],
      );
}, retry: (count, error) => null);

final activeTripProvider = StreamProvider<String>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        "SELECT value FROM app_settings WHERE key = 'active_trip'",
        readsFrom: {db.appSettings},
      )
      .watchSingleOrNull()
      .map((row) => row?.read<String>('value') ?? personalTripId);
}, retry: (count, error) => null);

final tripRatesProvider =
    StreamProvider.family<Map<String, TripCurrencyRate>, String>((ref, trip) {
      final db = ref.watch(databaseProvider);
      return db
          .customSelect(
            'SELECT currency_code, rate_to_myr, name FROM trip_rates WHERE trip_id = ?',
            variables: [Variable.withString(trip)],
            readsFrom: {db.tripRates},
          )
          .watch()
          .map(
            (rows) => {
              for (final row in rows)
                row.read<String>('currency_code'): (
                  rate: row.read<String>('rate_to_myr'),
                  name: row.readNullable<String>('name'),
                ),
            },
          );
    }, retry: (count, error) => null);

final tripActionsProvider = Provider(TripActions.new);

class TripActions {
  TripActions(this.ref);
  final Ref ref;

  Future<void> create(String input) async {
    final name = requiredText(input, label: 'Trip name', maxLength: 80);
    final db = ref.read(databaseProvider);
    await db.writeTransaction(() async {
      await db.customInsert(
        'INSERT INTO trips (id, name) VALUES (?, ?)',
        variables: [
          Variable.withString(const Uuid().v4()),
          Variable.withString(name),
        ],
        updates: {db.trips},
      );
    });
  }

  Future<void> activate(String id) async {
    final db = ref.read(databaseProvider);
    await db.writeTransaction(() async {
      final exists = await db
          .customSelect(
            'SELECT 1 FROM trips WHERE id = ?',
            variables: [Variable.withString(id)],
          )
          .getSingleOrNull();
      if (exists == null) {
        throw const LedgerException('Choose an existing trip.');
      }
      await db.customUpdate(
        """INSERT INTO app_settings (key, value) VALUES ('active_trip', ?)
           ON CONFLICT(key) DO UPDATE SET value = excluded.value""",
        variables: [Variable.withString(id)],
        updates: {db.appSettings},
      );
    });
  }

  Future<void> delete(String id) async {
    if (id == personalTripId) {
      throw const LedgerException('The Personal trip cannot be deleted.');
    }
    final db = ref.read(databaseProvider);
    await db.writeTransaction(() async {
      await db.customUpdate(
        "UPDATE transactions SET trip_id = 'personal' WHERE trip_id = ?",
        variables: [Variable.withString(id)],
        updates: {db.transactions},
      );
      await db.customUpdate(
        "DELETE FROM app_settings WHERE key = 'active_trip' AND value = ?",
        variables: [Variable.withString(id)],
        updates: {db.appSettings},
      );
      await db.customUpdate(
        'DELETE FROM trips WHERE id = ?',
        variables: [Variable.withString(id)],
        updates: {db.trips, db.tripRates},
      );
    });
  }

  Future<void> setRate(
    String trip,
    String code,
    String input, {
    String? name,
  }) async {
    if (code == 'MYR') throw const LedgerException('MYR is the base currency.');
    final label = name == null || name.trim().isEmpty
        ? null
        : requiredText(name, label: 'Currency name', maxLength: 80);
    final rate = input.trim().isEmpty ? null : normalizeExchangeRate(input);
    final db = ref.read(databaseProvider);
    await db.writeTransaction(() async {
      final keys = [Variable.withString(trip), Variable.withString(code)];
      if (rate == null) {
        await db.customUpdate(
          'DELETE FROM trip_rates WHERE trip_id = ? AND currency_code = ?',
          variables: keys,
          updates: {db.tripRates},
        );
      } else {
        await db.customUpdate(
          '''INSERT INTO trip_rates (trip_id, currency_code, rate_to_myr, name)
             VALUES (?, ?, ?, ?) ON CONFLICT(trip_id, currency_code)
             DO UPDATE SET rate_to_myr = excluded.rate_to_myr, name = excluded.name''',
          variables: [
            ...keys,
            Variable.withString(rate),
            Variable<String>(label),
          ],
          updates: {db.tripRates},
        );
      }
    });
  }
}
