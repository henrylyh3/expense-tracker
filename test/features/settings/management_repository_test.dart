import 'dart:async';

import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/ledger_category.dart';
import 'package:expense_tracker/features/currencies/data/currency_repository.dart';
import 'package:expense_tracker/features/currencies/domain/configured_currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CategoryRepository categories;
  late CurrencyRepository currencies;
  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.initialize();
    categories = CategoryRepository(database);
    currencies = CurrencyRepository(database);
  });
  tearDown(() => database.close());

  test('category create/edit/delete persists normalized values', () async {
    final id = await categories.save(_category('Travel'));
    await categories.save(_category('Trips'), id: id);
    expect((await categories.getById(id)).name, 'Trips');
    expect(await categories.remove(id), RemovalOutcome.deleted);
    await expectLater(categories.getById(id), throwsA(isA<LedgerException>()));
  });

  test(
    'category names are unique within type, including archived rows',
    () async {
      await _transaction(database);
      await categories.remove('seed-food');
      await expectLater(
        categories.save(_category('food')),
        throwsA(isA<LedgerException>()),
      );
      final id = await categories.save(
        _category('Food', type: TransactionType.income),
      );
      expect((await categories.getById(id)).type, TransactionType.income);
    },
  );

  test(
    'referenced category is archived/restorable and cannot change type',
    () async {
      await _transaction(database);
      expect(await categories.remove('seed-food'), RemovalOutcome.archived);
      expect((await categories.getById('seed-food')).isArchived, isTrue);
      await expectLater(
        categories.save(
          _category('Food', type: TransactionType.income),
          id: 'seed-food',
        ),
        throwsA(isA<LedgerException>()),
      );
      await categories.restore('seed-food');
      expect((await categories.getById('seed-food')).isArchived, isFalse);
      expect(
        await database.customSelect('SELECT * FROM transactions').get(),
        hasLength(1),
      );
    },
  );

  test('currency create/edit/rename/delete preserves creation time', () async {
    await currencies.save(_currency());
    final before = await database
        .customSelect(
          "SELECT created_at_utc FROM currencies WHERE code = 'USD'",
        )
        .getSingle();
    await currencies.save(
      _currency(code: 'USX', precision: 0),
      originalCode: 'USD',
    );
    expect((await currencies.getByCode('USX')).decimalPlaces, 0);
    final after = await database
        .customSelect(
          "SELECT created_at_utc FROM currencies WHERE code = 'USX'",
        )
        .getSingle();
    expect(
      after.read<int>('created_at_utc'),
      before.read<int>('created_at_utc'),
    );
    expect(await currencies.remove('USX'), RemovalOutcome.deleted);
  });

  test(
    'duplicate currency codes are rejected without modifying existing metadata',
    () async {
      await currencies.save(_currency());
      await expectLater(
        currencies.save(_currency(rate: '9')),
        throwsA(isA<LedgerException>()),
      );
      expect((await currencies.getByCode('USD')).rateToMyr, '4.5');
    },
  );

  test(
    'used currencies archive and retain identity while default rates remain editable',
    () async {
      await currencies.save(_currency());
      await _transaction(database, currency: 'USD', rate: '4.5', myr: 5625);
      await currencies.save(_currency(rate: '4.7'), originalCode: 'USD');
      final transaction = await database
          .customSelect('SELECT * FROM transactions')
          .getSingle();
      expect(transaction.read<String>('exchange_rate_snapshot'), '4.5');
      expect(transaction.read<int>('amount_myr_minor'), 5625);
      await expectLater(
        currencies.save(_currency(precision: 0), originalCode: 'USD'),
        throwsA(isA<LedgerException>()),
      );
      await expectLater(
        currencies.save(_currency(code: 'USX'), originalCode: 'USD'),
        throwsA(isA<LedgerException>()),
      );
      expect(await currencies.remove('USD'), RemovalOutcome.archived);
      await currencies.save(_currency(rate: '4.8'), originalCode: 'USD');
      expect((await currencies.getByCode('USD')).isActive, isFalse);
      await currencies.restore('USD');
      expect((await currencies.getByCode('USD')).isActive, isTrue);
    },
  );

  test('MYR permits metadata edits but cannot be removed or renamed', () async {
    await currencies.save(
      CurrencyDraft(
        code: 'MYR',
        name: 'Ringgit',
        symbol: 'RM',
        decimalPlaces: 2,
        rateToMyr: '1',
      ),
      originalCode: 'MYR',
    );
    expect((await currencies.getByCode('MYR')).name, 'Ringgit');
    await expectLater(
      currencies.remove('MYR'),
      throwsA(isA<LedgerException>()),
    );
    await expectLater(
      currencies.save(_currency(code: 'XYZ'), originalCode: 'MYR'),
      throwsA(isA<LedgerException>()),
    );
  });

  test(
    'category stream observes repository writes without manual invalidation',
    () async {
      final iterator = StreamIterator(categories.watchAll());
      try {
        expect(await iterator.moveNext(), isTrue);
        final id = await categories.save(_category('Travel'));
        expect(
          await iterator.moveNext().timeout(const Duration(seconds: 3)),
          isTrue,
        );
        expect(iterator.current.any((item) => item.id == id), isTrue);
      } finally {
        await iterator.cancel();
      }
    },
  );

  test(
    'currency stream usage count changes after a tracked transaction insert',
    () async {
      final iterator = StreamIterator(currencies.watchAll());
      try {
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.single.usageCount, 0);
        await database.customInsert(
          '''INSERT INTO transactions VALUES
        ('123e4567-e89b-42d3-a456-426614174000', 'seed-food', 'expense', 1250, 'MYR', '1', 1250, '2026-11-05', NULL, 0, 0)''',
          updates: {database.transactions},
        );
        expect(
          await iterator.moveNext().timeout(const Duration(seconds: 3)),
          isTrue,
        );
        expect(iterator.current.single.usageCount, 1);
      } finally {
        await iterator.cancel();
      }
    },
  );
}

CategoryDraft _category(
  String name, {
  TransactionType type = TransactionType.expense,
}) => CategoryDraft(
  name: name,
  type: type,
  iconKey: 'restaurant',
  colorHex: '#123456',
);
CurrencyDraft _currency({
  String code = 'USD',
  int precision = 2,
  String rate = '4.5',
}) => CurrencyDraft(
  code: code,
  name: 'US Dollar',
  symbol: r'$',
  decimalPlaces: precision,
  rateToMyr: rate,
);

Future<void> _transaction(
  AppDatabase database, {
  String currency = 'MYR',
  String rate = '1',
  int myr = 1250,
}) => database.customStatement(
  '''INSERT INTO transactions VALUES
  ('123e4567-e89b-42d3-a456-426614174000', 'seed-food', 'expense', 1250, ?, ?, ?, '2026-11-05', NULL, 0, 0)''',
  [currency, rate, myr],
);
