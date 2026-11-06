import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ledger_types.dart';
import '../money/display_currency.dart';
import 'database_providers.dart';

final defaultCurrencyProvider = StreamProvider<DisplayCurrency>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        """SELECT c.code, c.decimal_places, COALESCE(r.rate_to_myr, c.rate_to_myr) AS rate_to_myr
       FROM app_settings s JOIN currencies c ON c.code = s.value
       LEFT JOIN trip_rates r ON r.currency_code = c.code
         AND r.trip_id = COALESCE((SELECT value FROM app_settings WHERE key = 'active_trip'), 'personal')
       WHERE s.key = 'default_currency' AND c.is_active = 1""",
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
}, retry: (count, error) => null);

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
