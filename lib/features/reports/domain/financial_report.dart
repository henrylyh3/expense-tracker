import '../../../core/dates/calendar_date.dart';
import '../../../core/models/ledger_types.dart';
import '../../../core/money/money.dart';
import '../../../core/money/exchange_rate.dart';
import 'report_period.dart';

class ReportEntry {
  const ReportEntry({
    required this.type,
    required this.amountMyrMinor,
    required this.date,
    required this.categoryId,
    required this.categoryName,
    required this.categoryColorHex,
    required this.categoryIconKey,
    this.original,
    this.exchangeRate,
  });
  final TransactionType type;
  final int amountMyrMinor;
  final CalendarDate date;
  final String categoryId;
  final String categoryName;
  final String categoryColorHex;
  final String categoryIconKey;
  final Money? original;
  final String? exchangeRate;
}

class CategorySpending {
  const CategorySpending({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.iconKey,
    required this.amountMinor,
    required this.count,
  });
  final String id;
  final String name;
  final String colorHex;
  final String iconKey;
  final int amountMinor;
  final int count;
  Money get amount => _myr(amountMinor);
}

class TrendBucket {
  const TrendBucket({
    required this.date,
    required this.incomeMinor,
    required this.expenseMinor,
  });
  final CalendarDate date;
  final int incomeMinor;
  final int expenseMinor;
}

class FinancialReport {
  FinancialReport._({
    required this.period,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.netMinor,
    required this.incomeCount,
    required this.expenseCount,
    required List<CategorySpending> categories,
    required List<TrendBucket> buckets,
    required List<Money> currencyTotals,
    required Map<String, List<String>> currencyRates,
  }) : categories = List.unmodifiable(categories),
       buckets = List.unmodifiable(buckets),
       currencyTotals = List.unmodifiable(currencyTotals),
       currencyRates = Map.unmodifiable(
         currencyRates.map(
           (code, rates) => MapEntry(code, List<String>.unmodifiable(rates)),
         ),
       );

  factory FinancialReport.calculate(
    ReportPeriod period,
    Iterable<ReportEntry> entries,
  ) {
    var income = BigInt.zero;
    var expense = BigInt.zero;
    var incomeCount = 0;
    var expenseCount = 0;
    final incomeBuckets = List.filled(period.bucketCount, BigInt.zero);
    final expenseBuckets = List.filled(period.bucketCount, BigInt.zero);
    final tripDays = <CalendarDate, BigInt>{};
    final totals = <String, BigInt>{};
    final counts = <String, int>{};
    final metadata = <String, ReportEntry>{};
    final originalTotals = <String, BigInt>{};
    final originalPrecision = <String, int>{};
    final originalRates = <String, Set<String>>{};
    final start = period.start.toString();
    final end = period.endExclusive?.toString();
    for (final entry in entries) {
      final date = entry.date.toString();
      if (date.compareTo(start) < 0 ||
          (end != null && date.compareTo(end) >= 0)) {
        continue;
      }
      if (entry.amountMyrMinor < 0) {
        throw const LedgerException(
          'Report data contains an invalid MYR amount.',
        );
      }
      final value = BigInt.from(entry.amountMyrMinor);
      final bucket = period.isYear ? entry.date.month - 1 : entry.date.day - 1;
      if (entry.type == TransactionType.income) {
        income += value;
        incomeCount++;
        if (!period.isTrip) incomeBuckets[bucket] += value;
      } else {
        expense += value;
        expenseCount++;
        final original = entry.original;
        if (original != null) {
          final code = original.currencyCode;
          final priorPrecision =
              originalPrecision[code] ?? original.decimalPlaces;
          final precision = priorPrecision > original.decimalPlaces
              ? priorPrecision
              : original.decimalPlaces;
          originalTotals[code] =
              (originalTotals[code] ?? BigInt.zero) *
                  BigInt.from(10).pow(precision - priorPrecision) +
              BigInt.from(original.minorUnits) *
                  BigInt.from(10).pow(precision - original.decimalPlaces);
          originalPrecision[code] = precision;
          if (entry.exchangeRate != null) {
            originalRates
                .putIfAbsent(original.currencyCode, () => <String>{})
                .add(normalizeExchangeRate(entry.exchangeRate!));
          }
        }
        if (period.isTrip) {
          tripDays.update(
            entry.date,
            (total) => total + value,
            ifAbsent: () => value,
          );
        } else {
          expenseBuckets[bucket] += value;
        }
        totals.update(
          entry.categoryId,
          (old) => old + value,
          ifAbsent: () => value,
        );
        counts.update(entry.categoryId, (old) => old + 1, ifAbsent: () => 1);
        metadata[entry.categoryId] = entry;
      }
    }
    // Never SQLite SUM(integer), TOTAL(real), or double arithmetic. Overflow is
    // detected before narrowing, including when income/expense cancel in net.
    final checkedIncome = Money.checkedMinorUnits(income);
    final checkedExpense = Money.checkedMinorUnits(expense);
    final categories = [
      for (final item in totals.entries)
        CategorySpending(
          id: item.key,
          name: metadata[item.key]!.categoryName,
          colorHex: metadata[item.key]!.categoryColorHex,
          iconKey: metadata[item.key]!.categoryIconKey,
          amountMinor: Money.checkedMinorUnits(item.value),
          count: counts[item.key]!,
        ),
    ];
    categories.sort((a, b) {
      final byAmount = b.amountMinor.compareTo(a.amountMinor);
      if (byAmount != 0) return byAmount;
      final byName = a.name.compareTo(b.name);
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
    return FinancialReport._(
      period: period,
      incomeMinor: checkedIncome,
      expenseMinor: checkedExpense,
      netMinor: Money.checkedMinorUnits(income - expense),
      incomeCount: incomeCount,
      expenseCount: expenseCount,
      currencyTotals: [
        for (final code in (originalTotals.keys.toList()..sort()))
          Money.fromMinor(
            minorUnits: Money.checkedMinorUnits(originalTotals[code]!),
            currencyCode: code,
            decimalPlaces: originalPrecision[code]!,
          ),
      ],
      currencyRates: {
        for (final item in originalRates.entries)
          item.key: item.value.toList()..sort(),
      },
      categories: categories,
      buckets: period.isTrip
          ? [
              for (final day
                  in (tripDays.keys.toList()
                    ..sort((a, b) => a.toString().compareTo(b.toString()))))
                TrendBucket(
                  date: day,
                  incomeMinor: 0,
                  expenseMinor: Money.checkedMinorUnits(tripDays[day]!),
                ),
            ]
          : [
              for (var index = 0; index < period.bucketCount; index++)
                TrendBucket(
                  date: CalendarDate.parse(
                    '${period.year.toString().padLeft(4, '0')}-'
                    '${(period.isYear ? index + 1 : period.month!).toString().padLeft(2, '0')}-'
                    '${(period.isYear ? 1 : index + 1).toString().padLeft(2, '0')}',
                  ),
                  incomeMinor: Money.checkedMinorUnits(incomeBuckets[index]),
                  expenseMinor: Money.checkedMinorUnits(expenseBuckets[index]),
                ),
            ],
    );
  }

  final ReportPeriod period;
  final int incomeMinor;
  final int expenseMinor;
  final int netMinor;
  final int incomeCount;
  final int expenseCount;
  final List<CategorySpending> categories;
  final List<TrendBucket> buckets;
  final List<Money> currencyTotals;
  final Map<String, List<String>> currencyRates;
  int get transactionCount => incomeCount + expenseCount;
  Money get income => _myr(incomeMinor);
  Money get expenses => _myr(expenseMinor);
  Money get net => _myr(netMinor);
}

Money _myr(int value) =>
    Money.fromMinor(minorUnits: value, currencyCode: 'MYR', decimalPlaces: 2);
