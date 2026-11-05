import 'dart:async';

import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/dates/calendar_date.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/ledger_category.dart';
import 'package:expense_tracker/features/currencies/data/currency_repository.dart';
import 'package:expense_tracker/features/currencies/domain/configured_currency.dart';
import 'package:expense_tracker/features/reports/data/report_repository.dart';
import 'package:expense_tracker/features/reports/domain/report_period.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/transaction_filter.dart';
import 'package:expense_tracker/features/transactions/domain/transaction_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ReportRepository reports;
  late TransactionRepository transactions;
  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.initialize();
    reports = ReportRepository(database);
    transactions = TransactionRepository(database);
    await CurrencyRepository(database).save(
      CurrencyDraft(
        code: 'USD',
        name: 'Dollar',
        symbol: r'$',
        decimalPlaces: 2,
        rateToMyr: '4.5',
      ),
    );
  });
  tearDown(() => database.close());

  Future<String> add({
    String amount = '12.50',
    String currency = 'USD',
    String date = '2026-11-05',
    String? note,
    TransactionType type = TransactionType.expense,
    String? category,
  }) => transactions.save(
    TransactionInput(
      type: type,
      categoryId:
          category ??
          (type == TransactionType.income ? 'seed-salary' : 'seed-food'),
      currencyCode: currency,
      amountText: amount,
      date: CalendarDate.parse(date),
      note: note,
    ),
  );

  test(
    'monthly and yearly reports select correct date ranges and saved MYR facts',
    () async {
      await add();
      await add(
        currency: 'MYR',
        amount: '100',
        type: TransactionType.income,
        date: '2026-11-01',
      );
      await add(currency: 'MYR', amount: '1', date: '2026-10-31');
      await add(currency: 'MYR', amount: '2', date: '2026-12-01');
      final monthly = await reports
          .watchPeriod(ReportPeriod.month(2026, 11))
          .first;
      expect(monthly.incomeMinor, 10000);
      expect(monthly.expenseMinor, 5625);
      expect(monthly.netMinor, 4375);
      final yearly = await reports.watchPeriod(ReportPeriod.year(2026)).first;
      expect(yearly.expenseMinor, 5925);
      expect(yearly.transactionCount, 4);
    },
  );

  test(
    'default rates and archive flags do not rewrite historical report totals',
    () async {
      await add();
      await CurrencyRepository(database).save(
        CurrencyDraft(
          code: 'USD',
          name: 'Dollar',
          symbol: r'$',
          decimalPlaces: 2,
          rateToMyr: '4.7',
        ),
        originalCode: 'USD',
      );
      await CategoryRepository(database).remove('seed-food');
      await CurrencyRepository(database).remove('USD');
      final report = await reports
          .watchPeriod(ReportPeriod.month(2026, 11))
          .first;
      expect(report.expenseMinor, 5625);
      expect(report.categories.single.id, 'seed-food');
    },
  );

  test(
    'report streams react to category metadata while retaining stored amounts',
    () async {
      await add();
      final iterator = StreamIterator(
        reports.watchPeriod(ReportPeriod.month(2026, 11)),
      );
      try {
        expect(await iterator.moveNext(), isTrue);
        await CategoryRepository(database).save(
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
        expect(iterator.current.categories.single.name, 'Meals');
        expect(iterator.current.expenseMinor, 5625);
      } finally {
        await iterator.cancel();
      }
    },
  );

  test(
    'aggregate overflow is a deliberate domain error rather than SQLite SUM failure',
    () async {
      await add(currency: 'MYR', amount: '92233720368547758.07');
      await add(currency: 'MYR', amount: '0.01');
      await expectLater(
        reports.watchPeriod(ReportPeriod.month(2026, 11)).first,
        throwsA(isA<LedgerException>()),
      );
    },
  );

  test('empty periods and maximum supported calendar year work', () async {
    expect(
      (await reports.watchPeriod(ReportPeriod.month(2025, 1)).first)
          .transactionCount,
      0,
    );
    await add(currency: 'MYR', amount: '1', date: '9999-12-31');
    expect(
      (await reports.watchPeriod(ReportPeriod.year(9999)).first).expenseMinor,
      100,
    );
  });

  test(
    'all history filter fields combine with AND before pagination',
    () async {
      final wanted = await add(note: 'Lunch %_ 午餐');
      await add(currency: 'MYR', type: TransactionType.income, note: 'Lunch');
      await add(category: 'seed-shopping', note: 'Dinner');
      await add(date: '2026-12-05', note: 'Lunch');
      final result = await transactions
          .watchHistory(
            limit: 1,
            filter: TransactionFilter(
              query: 'lunch %_',
              type: TransactionType.expense,
              categoryId: 'seed-food',
              currencyCode: 'USD',
              from: CalendarDate.parse('2026-11-05'),
              to: CalendarDate.parse('2026-11-05'),
            ),
          )
          .first;
      expect(result.map((item) => item.id).toList(), [wanted]);
    },
  );

  test('search treats wildcard and SQL syntax as literal data', () async {
    final wanted = await add(note: 'Lunch %_ 午餐');
    await add(note: 'Ordinary lunch');
    expect(
      (await transactions
              .watchHistory(filter: TransactionFilter(query: '%_'))
              .first)
          .single
          .id,
      wanted,
    );
    expect(
      (await transactions
              .watchHistory(filter: TransactionFilter(query: '午餐'))
              .first)
          .single
          .id,
      wanted,
    );
    expect(
      await transactions
          .watchHistory(filter: TransactionFilter(query: "' OR 1=1 --"))
          .first,
      isEmpty,
    );
  });

  test(
    'date filters include both chosen days and support one-sided boundaries',
    () async {
      await add(date: '2026-11-04');
      final first = await add(date: '2026-11-05');
      final last = await add(date: '2026-11-06');
      final result = await transactions
          .watchHistory(
            filter: TransactionFilter(
              from: CalendarDate.parse('2026-11-05'),
              to: CalendarDate.parse('2026-11-06'),
            ),
          )
          .first;
      expect(result.map((item) => item.id).toSet(), {first, last});
      expect(
        (await transactions
                .watchHistory(
                  filter: TransactionFilter(
                    from: CalendarDate.parse('2026-11-06'),
                  ),
                )
                .first)
            .single
            .id,
        last,
      );
    },
  );

  test(
    'history filters retain archived category and currency references',
    () async {
      final id = await add();
      await CategoryRepository(database).remove('seed-food');
      await CurrencyRepository(database).remove('USD');
      final result = await transactions
          .watchHistory(
            filter: TransactionFilter(
              categoryId: 'seed-food',
              currencyCode: 'USD',
            ),
          )
          .first;
      expect(result.single.id, id);
      expect(result.single.categoryArchived, isTrue);
      expect(result.single.currencyActive, isFalse);
    },
  );

  test(
    'filtered pagination has a matching look-ahead row, not an unrelated row',
    () async {
      await add(note: 'Other', date: '2026-11-09');
      await add(note: 'Lunch', date: '2026-11-05');
      await add(note: 'Lunch', date: '2026-11-06');
      await add(note: 'Lunch', date: '2026-11-07');
      final page = await transactions
          .watchHistory(limit: 1, filter: TransactionFilter(query: 'Lunch'))
          .first;
      expect(page.map((item) => item.date.toString()).toList(), [
        '2026-11-07',
        '2026-11-06',
      ]);
    },
  );
}
