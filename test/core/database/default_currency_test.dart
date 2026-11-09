import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/providers/database_providers.dart';
import 'package:expense_tracker/core/providers/default_currency_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default currency persists and falls back when archived', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.initialize();
    await db.customStatement(
      "INSERT INTO currencies VALUES ('USD','Dollar','USD',2,'4.5',1,0,0)",
    );
    ProviderContainer container() {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      container.listen(defaultCurrencyProvider, (_, _) {});
      return container;
    }

    final first = container();
    expect((await first.read(defaultCurrencyProvider.future)).code, 'MYR');
    await first.read(defaultCurrencyActionsProvider.notifier).set('USD');
    first.dispose();

    final second = container();
    addTearDown(second.dispose);
    final saved = await second.read(defaultCurrencyProvider.future);
    expect(saved.code, 'USD');
    expect(saved.format(5625), 'USD 12.50');

    await db.customUpdate(
      "UPDATE currencies SET is_active = 0 WHERE code = 'USD'",
      updates: {db.currencies},
    );
    final third = container();
    addTearDown(third.dispose);
    expect((await third.read(defaultCurrencyProvider.future)).code, 'MYR');
  });
  test('one default overrides legacy trip preferences in every profile', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.initialize();
    await db.customStatement(
      "INSERT INTO currencies VALUES ('THB','Thai Baht','THB',2,'0.12',1,0,0)",
    );
    await db.customStatement(
      "INSERT INTO currency_rates (id, currency_code, name, rate_to_myr) VALUES ('thb-2026','THB','THB 2026','0.14')",
    );
    await db.customStatement(
      "INSERT INTO trips (id,name) VALUES ('holiday','Holiday')",
    );
    await db.customStatement(
      "INSERT INTO app_settings (key,value) VALUES ('trip_currency:personal','MYR'), ('trip_currency:holiday','THB')",
    );
    final writer = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(writer.dispose);
    await writer.read(defaultCurrencyActionsProvider.notifier).set('thb-2026');
    expect(writer.read(defaultCurrencyActionsProvider).hasError, isFalse);
    for (final trip in ['personal', 'holiday']) {
      await db.customStatement(
        "INSERT OR REPLACE INTO app_settings (key,value) VALUES ('active_trip', ?)",
        [trip],
      );
      final reader = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      reader.listen(defaultCurrencyProvider, (_, _) {});
      final selected = await reader.read(defaultCurrencyProvider.future);
      expect(selected.key, 'thb-2026');
      expect(selected.rateToMyr, '0.14');
      reader.dispose();
    }
    await writer.read(defaultCurrencyActionsProvider.notifier).set('MYR');
    final reader = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(reader.dispose);
    reader.listen(defaultCurrencyProvider, (_, _) {});
    expect((await reader.read(defaultCurrencyProvider.future)).key, 'MYR');
  });
}
