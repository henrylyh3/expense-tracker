import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ledger_types.dart';
import '../money/display_currency.dart';
import 'database_providers.dart';
import '../../features/currencies/data/currency_repository.dart';

final globalDefaultCurrencyProvider = StreamProvider<DisplayCurrency>(
  (ref) => watchDefaultCurrency(ref),
  retry: (count, error) => null,
);
final defaultCurrencyProvider = StreamProvider<DisplayCurrency>(
  (ref) => watchDefaultCurrency(ref),
  retry: (count, error) => null,
);

Stream<DisplayCurrency> watchDefaultCurrency(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        '''WITH records AS (
      SELECT c.code, c.code AS record_key, NULL AS record_id, c.decimal_places, c.rate_to_myr, c.is_active
      FROM currencies c
      UNION ALL SELECT c.code, r.id, r.id, c.decimal_places, r.rate_to_myr,
        CASE WHEN c.is_active = 1 THEN r.is_active ELSE 0 END
      FROM currency_rates r JOIN currencies c ON c.code = r.currency_code
    ), preference AS (
      SELECT COALESCE(
        (SELECT rc.record_key FROM records rc WHERE rc.is_active = 1 AND rc.record_key =
          COALESCE((SELECT value FROM app_settings WHERE key = 'default_rate'),
          (SELECT value FROM app_settings WHERE key = 'default_currency'))),
        'MYR') AS selected
    )
    SELECT rc.* FROM records rc JOIN preference p ON rc.record_key = p.selected''',
        readsFrom: {db.appSettings, db.currencies, db.currencyRates},
      )
      .watchSingleOrNull()
      .map(
        (row) => row == null
            ? DisplayCurrency.myr
            : DisplayCurrency(
                row.read<String>('code'),
                row.read<int>('decimal_places'),
                row.read<String>('rate_to_myr'),
                recordId: row.readNullable<String>('record_id'),
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
        final currency = await CurrencyRepository(db).getByCode(code);
        if (!currency.isActive) {
          throw const LedgerException('Choose an active currency.');
        }
        final active = await db
            .customSelect(
              'SELECT 1 FROM currencies WHERE code = ? AND is_active = 1',
              variables: [Variable.withString(currency.code)],
            )
            .getSingleOrNull();
        if (active == null) {
          throw const LedgerException('Choose an active currency.');
        }
        await db.customUpdate(
          """INSERT INTO app_settings (key, value) VALUES ('default_currency', ?)
           ON CONFLICT(key) DO UPDATE SET value = excluded.value""",
          variables: [Variable.withString(currency.code)],
          updates: {db.appSettings},
        );
        await db.customUpdate(
          "DELETE FROM app_settings WHERE key = 'default_rate'",
          updates: {db.appSettings},
        );
        if (currency.recordId != null) {
          await db.customUpdate(
            "INSERT INTO app_settings (key, value) VALUES ('default_rate', ?)",
            variables: [Variable.withString(currency.key)],
            updates: {db.appSettings},
          );
        }
      }),
    );
    if (ref.mounted) state = result;
  }
}
