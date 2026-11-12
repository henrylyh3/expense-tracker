import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/dates/date_labels.dart';
import '../../../core/money/money.dart';
import '../../../core/money/display_currency.dart';
import '../../../shared/widgets/category_appearance.dart';
import '../domain/financial_report.dart';

class FinancialSummary extends StatelessWidget {
  const FinancialSummary({
    required this.report,
    this.currency = DisplayCurrency.myr,
    super.key,
  });
  final FinancialReport report;
  final DisplayCurrency currency;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('${report.expenseCount} expenses · Displayed in ${currency.code}'),
      const SizedBox(height: 12),
      _summaryCard(
        context,
        double.infinity,
        'Expenses',
        report.expenseMinor,
        Theme.of(context).colorScheme.error,
      ),
    ],
  );
  Widget _summaryCard(
    BuildContext context,
    double width,
    String label,
    int value,
    Color color,
  ) => SizedBox(
    width: width,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                currency.format(value),
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TripCurrencySummary extends StatelessWidget {
  const TripCurrencySummary({
    required this.expenseCount,
    required this.currencyTotals,
    required this.expenses,
    this.currencyRates = const {},
    super.key,
  });
  final int expenseCount;
  final List<Money> currencyTotals;
  final Money expenses;
  final Map<String, List<String>> currencyRates;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('$expenseCount expenses'),
      const SizedBox(height: 12),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spent by currency',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                currencyRates.isEmpty
                    ? 'Original expense amounts.'
                    : 'Original expense amounts and saved exchange rates.',
              ),
              if (expenseCount == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('No expenses in this trip.'),
                ),
              for (final total in currencyTotals)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          total.format(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      for (final rate
                          in currencyRates[total.currencyCode] ??
                              const <String>[])
                        Text('1 ${total.currencyCode} = $rate MYR'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total in MYR',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  expenses.format(),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Combined using each expense’s saved exchange rate.'),
            ],
          ),
        ),
      ),
    ],
  );
}

class SpendingBreakdown extends StatelessWidget {
  const SpendingBreakdown({
    required this.categories,
    this.currency = DisplayCurrency.myr,
    this.onCategory,
    super.key,
  });
  final List<CategorySpending> categories;
  final DisplayCurrency currency;
  final ValueChanged<CategorySpending>? onCategory;
  @override
  Widget build(BuildContext context) {
    final positive = categories.where((item) => item.amountMinor > 0).toList();
    final slices = positive
        .take(5)
        .map(
          (item) => (
            name: item.name,
            color: categoryColor(item.colorHex),
            minor: item.amountMinor,
          ),
        )
        .toList();
    if (positive.length > 5) {
      final other = positive
          .skip(5)
          .fold<BigInt>(
            BigInt.zero,
            (total, item) => total + BigInt.from(item.amountMinor),
          );
      slices.add((
        name: 'Other',
        color: const Color(0xFF78909C),
        minor: Money.checkedMinorUnits(other),
      ));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Expenses by category',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (positive.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No spending in this period.'),
              )
            else ...[
              Semantics(
                label: 'Spending by category in ${currency.code}.',
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 32,
                        sectionsSpace: 3,
                        pieTouchData: PieTouchData(enabled: false),
                        sections: [
                          for (final slice in slices)
                            PieChartSectionData(
                              value: slice.minor.toDouble(),
                              color: slice.color,
                              radius: 65,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final slice in slices)
                    _Legend(color: slice.color, label: slice.name),
                ],
              ),
              if (positive.length > 5)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Top five categories shown; remaining categories are combined in the chart.',
                  ),
                ),
            ],
            for (final item in categories)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  categoryIcons[item.iconKey] ?? Icons.more_horiz,
                  color: categoryColor(item.colorHex),
                ),
                title: Text(item.name),
                subtitle: Text(
                  '${currency.format(item.amountMinor)} · ${item.count} transactions',
                ),
                onTap: onCategory == null ? null : () => onCategory!(item),
              ),
          ],
        ),
      ),
    );
  }
}

class CashFlowTrend extends StatelessWidget {
  const CashFlowTrend({
    required this.report,
    this.currency = DisplayCurrency.myr,
    this.title,
    super.key,
  });
  final FinancialReport report;
  final DisplayCurrency currency;
  final String? title;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maximum = report.buckets.fold<int>(
      0,
      (value, bucket) => math.max(value, bucket.expenseMinor),
    );
    String label(TrendBucket bucket) => report.period.isTrip
        ? '${bucket.date.day}/${bucket.date.month}'
        : report.period.isYear
        ? monthLabel(bucket.date)
        : dayLabel(bucket.date);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title ??
                  (report.period.isYear
                      ? 'Monthly expenses'
                      : 'Daily expenses'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('${currency.code} · Values below'),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [_Legend(color: colors.error, label: 'Expenses')],
            ),
            if (maximum == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No expenses to chart in this period.'),
              )
            else
              Semantics(
                label:
                    'Expense trends in ${currency.code}. Values are available below.',
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 240,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: BarChart(
                        BarChartData(
                          minY: 0,
                          maxY: currency.chartValue(maximum) * 1.15,
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(drawVerticalLine: false),
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(),
                            rightTitles: const AxisTitles(),
                            leftTitles: const AxisTitles(),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize:
                                    MediaQuery.textScalerOf(context).scale(12) +
                                    16,
                                getTitlesWidget: (value, meta) {
                                  final index = value.round();
                                  if (index < 0 ||
                                      index >= report.buckets.length ||
                                      index %
                                              (report.period.isTrip
                                                  ? math.max(
                                                      1,
                                                      (report.buckets.length /
                                                              5)
                                                          .ceil(),
                                                    )
                                                  : report.period.isYear
                                                  ? 3
                                                  : 7) !=
                                          0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      label(report.buckets[index]),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          // Doubles are only chart coordinates. All labels/totals retain exact integers.
                          barGroups: [
                            for (
                              var index = 0;
                              index < report.buckets.length;
                              index++
                            )
                              BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: currency.chartValue(
                                      report.buckets[index].expenseMinor,
                                    ),
                                    color: colors.error,
                                    width: report.period.isYear ? 7 : 3,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('View exact values'),
              children: [
                for (final bucket in report.buckets)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(label(bucket)),
                    subtitle: Text(
                      'Expenses: ${currency.format(bucket.expenseMinor)}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      const SizedBox(width: 6),
      Flexible(child: Text(label)),
    ],
  );
}
