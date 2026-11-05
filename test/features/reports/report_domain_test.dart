import 'package:expense_tracker/core/dates/calendar_date.dart';
import 'package:expense_tracker/core/dates/date_labels.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/core/money/money.dart';
import 'package:expense_tracker/features/reports/domain/financial_report.dart';
import 'package:expense_tracker/features/reports/domain/report_period.dart';
import 'package:expense_tracker/features/transactions/data/history_predicate.dart';
import 'package:expense_tracker/features/transactions/domain/transaction_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'English calendar labels work offline without date-symbol initialization',
    () {
      final date = CalendarDate.parse('2026-11-05');
      expect(monthYearLabel(date), 'November 2026');
      expect(monthLabel(date), 'Nov');
      expect(dayLabel(date), '5');
    },
  );
  test(
    'monthly totals use inclusive start and exclusive next-month boundary',
    () {
      final report = FinancialReport.calculate(ReportPeriod.month(2026, 11), [
        _entry(date: '2026-10-31', amount: 999),
        _entry(date: '2026-11-01', amount: 10000, type: TransactionType.income),
        _entry(date: '2026-11-30', amount: 2500),
        _entry(date: '2026-12-01', amount: 999),
      ]);
      expect(report.incomeMinor, 10000);
      expect(report.expenseMinor, 2500);
      expect(report.netMinor, 7500);
      expect(report.transactionCount, 2);
      expect(report.buckets.first.incomeMinor, 10000);
      expect(report.buckets.last.expenseMinor, 2500);
    },
  );

  test('yearly reports fill twelve monthly buckets without crossing years', () {
    final report = FinancialReport.calculate(ReportPeriod.year(2026), [
      _entry(date: '2025-12-31', amount: 999),
      _entry(date: '2026-01-01', amount: 100),
      _entry(date: '2026-12-31', amount: 200, type: TransactionType.income),
      _entry(date: '2027-01-01', amount: 999),
    ]);
    expect(report.buckets, hasLength(12));
    expect(report.buckets.first.expenseMinor, 100);
    expect(report.buckets[1].expenseMinor, 0);
    expect(report.buckets.last.incomeMinor, 200);
    expect(report.netMinor, 100);
  });

  test('leap-year daily buckets include February 29', () {
    final report = FinancialReport.calculate(ReportPeriod.month(2024, 2), [
      _entry(date: '2024-02-29', amount: 123),
    ]);
    expect(report.buckets, hasLength(29));
    expect(report.buckets.last.expenseMinor, 123);
    expect(ReportPeriod.month(1900, 2).bucketCount, 28);
  });

  test('empty reports have exact zeros and zero-filled trends', () {
    final report = FinancialReport.calculate(
      ReportPeriod.month(2026, 11),
      const [],
    );
    expect(report.incomeMinor, 0);
    expect(report.expenseMinor, 0);
    expect(report.netMinor, 0);
    expect(report.categories, isEmpty);
    expect(report.buckets, hasLength(30));
    expect(
      report.buckets.every(
        (item) => item.incomeMinor == 0 && item.expenseMinor == 0,
      ),
      isTrue,
    );
  });

  test('net can be negative while original totals remain positive MYR', () {
    final report = FinancialReport.calculate(ReportPeriod.month(2026, 11), [
      _entry(amount: 500),
      _entry(amount: 100, type: TransactionType.income),
    ]);
    expect(report.netMinor, -400);
    expect(report.net.currencyCode, 'MYR');
    expect(report.net.format(), contains('4.00'));
  });

  test('spending groups by category ID rather than display name', () {
    final report = FinancialReport.calculate(ReportPeriod.month(2026, 11), [
      _entry(category: 'a', name: 'Food', amount: 100),
      _entry(category: 'a', name: 'Meals', amount: 200),
      _entry(category: 'b', name: 'Meals', amount: 50),
    ]);
    expect(report.categories, hasLength(2));
    expect(report.categories.first.id, 'a');
    expect(report.categories.first.name, 'Meals');
    expect(report.categories.first.amountMinor, 300);
    expect(report.categories.first.count, 2);
  });

  test('income is excluded from spending breakdown but retained in totals', () {
    final report = FinancialReport.calculate(ReportPeriod.month(2026, 11), [
      _entry(amount: 500),
      _entry(category: 'salary', amount: 1000, type: TransactionType.income),
    ]);
    expect(report.categories.single.id, 'food');
    expect(report.incomeCount, 1);
    expect(report.expenseCount, 1);
  });

  test(
    'zero-sen converted expenses retain transaction and category counts',
    () {
      final report = FinancialReport.calculate(ReportPeriod.month(2026, 11), [
        _entry(amount: 0),
      ]);
      expect(report.expenseMinor, 0);
      expect(report.transactionCount, 1);
      expect(report.categories.single.count, 1);
    },
  );

  test(
    'aggregate overflow is rejected even when income and expenses cancel',
    () {
      final maximum = Money.maxMinorUnits.toInt();
      expect(
        () => FinancialReport.calculate(ReportPeriod.month(2026, 11), [
          _entry(amount: maximum),
          _entry(amount: 1),
          _entry(amount: maximum, type: TransactionType.income),
          _entry(amount: 1, type: TransactionType.income),
        ]),
        throwsA(isA<LedgerException>()),
      );
    },
  );

  test('negative persisted MYR amounts are rejected', () {
    expect(
      () => FinancialReport.calculate(ReportPeriod.month(2026, 11), [
        _entry(amount: -1),
      ]),
      throwsA(isA<LedgerException>()),
    );
  });

  test('report result collections cannot be mutated by views', () {
    final report = FinancialReport.calculate(ReportPeriod.month(2026, 11), [
      _entry(),
    ]);
    expect(() => report.categories.clear(), throwsUnsupportedError);
    expect(() => report.buckets.clear(), throwsUnsupportedError);
  });

  test(
    'calendar upper bound never generates an incorrectly sortable five-digit end',
    () {
      final year = ReportPeriod.year(9999);
      expect(year.endExclusive, isNull);
      expect(year.lastDay.toString(), '9999-12-31');
      expect(year.contains(CalendarDate.parse('9999-12-31')), isTrue);
      expect(year.shift(1), isNull);
      expect(ReportPeriod.month(9999, 12).endExclusive, isNull);
      expect(
        ReportPeriod.month(9999, 11).contains(CalendarDate.parse('9999-12-01')),
        isFalse,
      );
      expect(ReportPeriod.year(1).start.toString(), '0001-01-01');
      expect(ReportPeriod.year(1).shift(-1), isNull);
    },
  );

  test(
    'period selection validates ranges, shifts across years and has value equality',
    () {
      expect(
        ReportPeriod.month(2026, 12).shift(1),
        ReportPeriod.month(2027, 1),
      );
      expect(
        ReportPeriod.month(2026, 11).hashCode,
        ReportPeriod.month(2026, 11).hashCode,
      );
      expect(ReportPeriod.year(2026), isNot(ReportPeriod.month(2026, 1)));
      expect(
        () => ReportPeriod.month(2026, 0),
        throwsA(isA<LedgerException>()),
      );
      expect(() => ReportPeriod.year(0), throwsA(isA<LedgerException>()));
    },
  );

  test(
    'filters normalize values and reject reversed dates and oversized searches',
    () {
      final filter = TransactionFilter(
        query: ' lunch ',
        currencyCode: ' usd ',
        categoryId: ' food ',
      );
      expect(filter.query, 'lunch');
      expect(filter.currencyCode, 'USD');
      expect(filter.categoryId, 'food');
      expect(
        () => TransactionFilter(
          from: CalendarDate.parse('2026-11-06'),
          to: CalendarDate.parse('2026-11-05'),
        ),
        throwsA(isA<LedgerException>()),
      );
      expect(
        () => TransactionFilter(query: List.filled(201, 'a').join()),
        throwsA(isA<LedgerException>()),
      );
    },
  );

  test('updating search preserves all field filters and calendar equality', () {
    final filter = TransactionFilter(
      type: TransactionType.expense,
      currencyCode: 'USD',
      from: CalendarDate.parse('2026-11-01'),
      to: CalendarDate.parse('2026-11-30'),
    );
    final changed = filter.withQuery('food');
    expect(changed.type, filter.type);
    expect(changed.from, CalendarDate.parse('2026-11-01'));
    expect(changed.currencyCode, 'USD');
    expect(changed.fieldCount, 3);
    expect(const TransactionFilter.empty().hasConstraints, isFalse);
  });

  test('search and category text is bound as data, never interpolated SQL', () {
    const query = "' OR 1=1 -- %_";
    final predicate = buildHistoryPredicate(
      TransactionFilter(query: query, categoryId: query),
    );
    expect(predicate.sql, isNot(contains(query)));
    expect(predicate.arguments.where((value) => value == query), hasLength(4));
    expect(predicate.sql, contains('instr('));
    expect(buildHistoryPredicate(const TransactionFilter.empty()).sql, isEmpty);
  });
}

ReportEntry _entry({
  String date = '2026-11-05',
  int amount = 100,
  String category = 'food',
  String name = 'Food',
  TransactionType type = TransactionType.expense,
}) => ReportEntry(
  type: type,
  amountMyrMinor: amount,
  date: CalendarDate.parse(date),
  categoryId: category,
  categoryName: name,
  categoryColorHex: '#123456',
  categoryIconKey: 'restaurant',
);
