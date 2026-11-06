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
}
