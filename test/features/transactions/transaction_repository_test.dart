import 'dart:async';

import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/dates/calendar_date.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/ledger_category.dart';
import 'package:expense_tracker/features/currencies/data/currency_repository.dart';
import 'package:expense_tracker/features/currencies/domain/configured_currency.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/transaction_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late TransactionRepository transactions;
  late CurrencyRepository currencies;
  late CategoryRepository categories;
  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.initialize();
    transactions = TransactionRepository(database);
    currencies = CurrencyRepository(database);
    categories = CategoryRepository(database);
    await currencies.save(_usd('4.5'));
  });
  tearDown(() => database.close());

  test('persists original amount, currency, rate and MYR equivalent', () async {
    final id = await transactions.save(_input());
    final item = await transactions.getById(id);
    expect(item.conversion.original.minorUnits, 1250);
    expect(item.conversion.original.currencyCode, 'USD');
    expect(item.conversion.exchangeRate, '4.5');
    expect(item.conversion.myr.minorUnits, 5625);
    expect(item.createdAtUtc, item.updatedAtUtc);
  });

  test('MYR identity and JPY/KRW precision are persisted', () async {
    for (final (code, precision, rate, amount, minor, myr) in [
      ('MYR', 2, '1', '12.50', 1250, 1250),
      ('JPY', 0, '0.03', '500', 500, 1500),
      ('KRW', 0, '0.0034', '15000', 15000, 5100),
    ]) {
      if (code != 'MYR') {
        await currencies.save(
          CurrencyDraft(
            code: code,
            name: code,
            symbol: code,
            decimalPlaces: precision,
            rateToMyr: rate,
          ),
        );
      }
      final saved = await transactions.getById(
        await transactions.save(_input(currency: code, amount: amount)),
      );
      expect(saved.conversion.original.minorUnits, minor);
      expect(saved.conversion.original.currencyCode, code);
      expect(saved.conversion.myr.minorUnits, myr);
    }
  });

  test(
    'new defaults affect new entries while metadata edits preserve snapshots',
    () async {
      final id = await transactions.save(_input());
      final before = await transactions.getById(id);
      await currencies.save(_usd('4.7'), originalCode: 'USD');
      final newItem = await transactions.getById(
        await transactions.save(_input()),
      );
      expect(newItem.conversion.myr.minorUnits, 5875);
      await transactions.save(
        _input(note: 'Lunch', category: 'seed-shopping', date: '2026-11-04'),
        id: id,
        expectedUpdatedAtUtc: before.updatedAtUtc,
      );
      final after = await transactions.getById(id);
      expect(after.conversion.exchangeRate, '4.5');
      expect(after.conversion.myr.minorUnits, 5625);
      expect(after.createdAtUtc, before.createdAtUtc);
      expect(after.updatedAtUtc, greaterThan(before.updatedAtUtc));
      expect(after.note, 'Lunch');
      expect(after.date.toString(), '2026-11-04');
    },
  );

  test(
    'amount edits use saved rate and explicit conversion edits recalculate',
    () async {
      final id = await transactions.save(_input());
      final before = await transactions.getById(id);
      await currencies.save(_usd('4.7'), originalCode: 'USD');
      await transactions.save(
        _input(amount: '20'),
        id: id,
        expectedUpdatedAtUtc: before.updatedAtUtc,
      );
      final amountEdit = await transactions.getById(id);
      expect(amountEdit.conversion.myr.minorUnits, 9000);
      await transactions.save(
        _input(amount: '20', rate: '4.7'),
        id: id,
        expectedUpdatedAtUtc: amountEdit.updatedAtUtc,
      );
      expect((await transactions.getById(id)).conversion.myr.minorUnits, 9400);
    },
  );

  test(
    'currency changes require confirmation and the explicitly chosen rate',
    () async {
      await currencies.save(
        CurrencyDraft(
          code: 'JPY',
          name: 'Yen',
          symbol: '¥',
          decimalPlaces: 0,
          rateToMyr: '0.03',
        ),
      );
      final id = await transactions.save(_input());
      final before = await transactions.getById(id);
      await expectLater(
        transactions.save(
          _input(currency: 'JPY', amount: '500'),
          id: id,
          expectedUpdatedAtUtc: before.updatedAtUtc,
        ),
        throwsA(isA<LedgerException>()),
      );
      await transactions.save(
        _input(currency: 'JPY', amount: '500', rate: '0.03', confirmed: true),
        id: id,
        expectedUpdatedAtUtc: before.updatedAtUtc,
      );
      final after = await transactions.getById(id);
      expect(after.conversion.original.currencyCode, 'JPY');
      expect(after.conversion.myr.minorUnits, 1500);
    },
  );

  test(
    'archived original references may be retained but cannot be used for new entries',
    () async {
      final id = await transactions.save(_input());
      final before = await transactions.getById(id);
      await categories.remove('seed-food');
      await currencies.remove('USD');
      await transactions.save(
        _input(note: 'Historical edit'),
        id: id,
        expectedUpdatedAtUtc: before.updatedAtUtc,
      );
      expect((await transactions.getById(id)).note, 'Historical edit');
      await expectLater(
        transactions.save(_input()),
        throwsA(isA<LedgerException>()),
      );
      await expectLater(
        transactions.save(_input(category: 'seed-shopping')),
        throwsA(isA<LedgerException>()),
      );
    },
  );

  test('editing cannot switch to a different archived category', () async {
    final id = await transactions.save(_input());
    final before = await transactions.getById(id);
    await database.customStatement(
      "UPDATE categories SET is_archived = 1 WHERE id = 'seed-shopping'",
    );
    await expectLater(
      transactions.save(
        _input(category: 'seed-shopping'),
        id: id,
        expectedUpdatedAtUtc: before.updatedAtUtc,
      ),
      throwsA(isA<LedgerException>()),
    );
    expect((await transactions.getById(id)).categoryId, 'seed-food');
  });

  test(
    'stale saves and deletes fail without overwriting a newer edit',
    () async {
      final id = await transactions.save(_input());
      final before = await transactions.getById(id);
      await transactions.save(
        _input(note: 'First edit'),
        id: id,
        expectedUpdatedAtUtc: before.updatedAtUtc,
      );
      await expectLater(
        transactions.save(
          _input(note: 'Stale edit'),
          id: id,
          expectedUpdatedAtUtc: before.updatedAtUtc,
        ),
        throwsA(isA<LedgerException>()),
      );
      await expectLater(
        transactions.delete(id, expectedUpdatedAtUtc: before.updatedAtUtc),
        throwsA(isA<LedgerException>()),
      );
      final current = await transactions.getById(id);
      expect(current.note, 'First edit');
      await transactions.delete(id, expectedUpdatedAtUtc: current.updatedAtUtc);
      await expectLater(
        transactions.getById(id),
        throwsA(isA<LedgerException>()),
      );
    },
  );

  test(
    'rejects invalid money and type mismatches without partial inserts',
    () async {
      await expectLater(
        transactions.save(_input(amount: '0')),
        throwsA(isA<LedgerException>()),
      );
      await expectLater(
        transactions.save(_input(amount: '1.0000001')),
        throwsA(isA<LedgerException>()),
      );
      await expectLater(
        transactions.save(_input(type: TransactionType.income)),
        throwsA(isA<LedgerException>()),
      );
      await expectLater(
        transactions.save(_input(amount: '92233720368547758.07')),
        throwsA(isA<LedgerException>()),
      );
      expect(
        await database.customSelect('SELECT * FROM transactions').get(),
        isEmpty,
      );
    },
  );

  test(
    'history uses date ordering with a look-ahead row for incremental loading',
    () async {
      await transactions.save(_input(date: '2026-11-01'));
      await transactions.save(_input(date: '2026-11-03'));
      await transactions.save(_input(date: '2026-11-02'));
      final page = await transactions.watchHistory(limit: 1).first;
      expect(page, hasLength(2));
      expect(page.map((item) => item.date.toString()).toList(), [
        '2026-11-03',
        '2026-11-02',
      ]);
    },
  );

  test(
    'history reacts to current category metadata changes without altering money',
    () async {
      await transactions.save(_input());
      final iterator = StreamIterator(transactions.watchHistory());
      try {
        expect(await iterator.moveNext(), isTrue);
        await categories.save(
          CategoryDraft(
            name: 'Meals',
            type: TransactionType.expense,
            iconKey: 'restaurant',
            colorHex: '#123456',
          ),
          id: 'seed-food',
        );
        expect(
          await iterator.moveNext().timeout(const Duration(seconds: 3)),
          isTrue,
        );
        expect(iterator.current.single.categoryName, 'Meals');
        expect(iterator.current.single.conversion.myr.minorUnits, 5625);
      } finally {
        await iterator.cancel();
      }
    },
  );

  test(
    'deleting a transaction updates currency reference counts reactively',
    () async {
      final id = await transactions.save(_input());
      final item = await transactions.getById(id);
      final iterator = StreamIterator(currencies.watchAll());
      try {
        expect(await iterator.moveNext(), isTrue);
        expect(
          iterator.current
              .firstWhere((currency) => currency.code == 'USD')
              .usageCount,
          1,
        );
        await transactions.delete(id, expectedUpdatedAtUtc: item.updatedAtUtc);
        expect(
          await iterator.moveNext().timeout(const Duration(seconds: 3)),
          isTrue,
        );
        expect(
          iterator.current
              .firstWhere((currency) => currency.code == 'USD')
              .usageCount,
          0,
        );
      } finally {
        await iterator.cancel();
      }
    },
  );
}

CurrencyDraft _usd(String rate) => CurrencyDraft(
  code: 'USD',
  name: 'Dollar',
  symbol: r'$',
  decimalPlaces: 2,
  rateToMyr: rate,
);
TransactionInput _input({
  String amount = '12.50',
  String currency = 'USD',
  String category = 'seed-food',
  String date = '2026-11-05',
  String? note,
  String? rate,
  bool confirmed = false,
  TransactionType type = TransactionType.expense,
}) => TransactionInput(
  type: type,
  categoryId: category,
  currencyCode: currency,
  amountText: amount,
  date: CalendarDate.parse(date),
  note: note,
  rateOverride: rate,
  currencyChangeConfirmed: confirmed,
);
