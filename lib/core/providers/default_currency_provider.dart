import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ledger_types.dart';
import '../money/display_currency.dart';
import 'database_providers.dart';

final globalDefaultCurrencyProvider = StreamProvider<DisplayCurrency>(
  (ref) => watchDefaultCurrency(ref, tripDefaults: false),
  retry: (count, error) => null,
);
final defaultCurrencyProvider = StreamProvider<DisplayCurrency>(
  (ref) => watchDefaultCurrency(ref, tripDefaults: true),
  retry: (count, error) => null,
);

final tripDefaultCurrencyProvider =
    StreamProvider.family<DisplayCurrency, String>(
      (ref, id) => watchDefaultCurrency(ref, tripDefaults: true, tripId: id),
      retry: (count, error) => null,
    );

Stream<DisplayCurrency> watchDefaultCurrency(
  Ref ref, {
  required bool tripDefaults,
  String? tripId,
}) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        """SELECT c.code, c.decimal_places, COALESCE(r.rate_to_myr, c.rate_to_myr) AS rate_to_myr
       FROM currencies c
       LEFT JOIN trip_rates r ON r.currency_code = c.code
         AND r.trip_id = COALESCE(?, (SELECT value FROM app_settings WHERE key = 'active_trip'), 'personal')
       WHERE c.code = COALESCE(
         CASE WHEN ? = 1 THEN (SELECT ts.value FROM app_settings ts
           JOIN currencies tc ON tc.code = ts.value AND tc.is_active = 1
           WHERE ts.key = 'trip_currency:' || COALESCE(?, (SELECT value FROM app_settings WHERE key = 'active_trip'), 'personal')) END,
         (SELECT gs.value FROM app_settings gs JOIN currencies gc ON gc.code = gs.value AND gc.is_active = 1
          WHERE gs.key = 'default_currency'), 'MYR') AND c.is_active = 1""",
        variables: [
          Variable<String>(tripId),
          Variable.withInt(tripDefaults ? 1 : 0),
          Variable<String>(tripId),
        ],
        readsFrom: {db.appSettings, db.currencies, db.tripRates},
      )
      .watchSingleOrNull()
      .map(
        (row) => row == null
            ? DisplayCurrency.myr
            : DisplayCurrency(
                row.read<String>('code'),
                row.read<int>('decimal_places'),
                row.read<String>('rate_to_myr'),
              ),
      );
}

final defaultCurrencyActionsProvider =
    AsyncNotifierProvider<DefaultCurrencyActions, void>(
      DefaultCurrencyActions.new,
    );

class DefaultCurrencyActions extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> set(String code) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final db = ref.read(databaseProvider);
    final result = await AsyncValue.guard<void>(
      () => db.writeTransaction(() async {
        final active = await db
            .customSelect(
              'SELECT 1 FROM currencies WHERE code = ? AND is_active = 1',
              variables: [Variable.withString(code)],
            )
            .getSingleOrNull();
        if (active == null) {
          throw const LedgerException('Choose an active currency.');
        }
        await db.customUpdate(
          """INSERT INTO app_settings (key, value) VALUES ('default_currency', ?)
           ON CONFLICT(key) DO UPDATE SET value = excluded.value""",
          variables: [Variable.withString(code)],
          updates: {db.appSettings},
        );
      }),
    );
    if (ref.mounted) state = result;
  }
}
