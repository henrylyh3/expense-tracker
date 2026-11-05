import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/dates/date_labels.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/category_appearance.dart';
import '../domain/financial_report.dart';
import '../domain/report_period.dart';

String periodLabel(ReportPeriod period) =>
    period.isYear ? '${period.year}' : monthYearLabel(period.start);

class PeriodControl extends StatelessWidget {
  const PeriodControl({
    required this.period,
    required this.onMove,
    required this.onToday,
    this.onYearlyChanged,
    super.key,
  });
  final ReportPeriod period;
  final ValueChanged<int> onMove;
  final VoidCallback onToday;
  final ValueChanged<bool>? onYearlyChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          IconButton(
            tooltip: 'Previous period',
            onPressed: period.shift(-1) == null ? null : () => onMove(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              periodLabel(period),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Next period',
            onPressed: period.shift(1) == null ? null : () => onMove(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (onYearlyChanged != null) ...[
            ChoiceChip(
              label: const Text('Monthly'),
              selected: !period.isYear,
              onSelected: (_) => onYearlyChanged!(false),
            ),
            ChoiceChip(
              label: const Text('Yearly'),
              selected: period.isYear,
              onSelected: (_) => onYearlyChanged!(true),
            ),
          ],
          TextButton(onPressed: onToday, child: const Text('Current period')),
        ],
      ),
    ],
  );
}

class FinancialSummary extends StatelessWidget {
  const FinancialSummary({required this.report, super.key});
  final FinancialReport report;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${report.transactionCount} transactions · Saved conversions in MYR',
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 700
              ? (constraints.maxWidth - 24) / 3
              : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _summaryCard(
                context,
                width,
                'Income',
                report.income,
                Theme.of(context).colorScheme.primary,
              ),
              _summaryCard(
                context,
                width,
                'Expenses',
                report.expenses,
                Theme.of(context).colorScheme.error,
              ),
              _summaryCard(
                context,
                width,
                'Net cash flow',
                report.net,
                Theme.of(context).colorScheme.onSurface,
              ),
            ],
          );
        },
      ),
    ],
  );
  Widget _summaryCard(
    BuildContext context,
    double width,
    String label,
    Money value,
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
                value.format(),
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

class SpendingBreakdown extends StatelessWidget {
  const SpendingBreakdown({required this.report, this.onCategory, super.key});
  final FinancialReport report;
  final ValueChanged<CategorySpending>? onCategory;
  @override
  Widget build(BuildContext context) {
    final positive = report.categories
        .where((item) => item.amountMinor > 0)
        .toList();
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
                child: Text('No MYR spending in this period.'),
              )
            else ...[
              Semantics(
                label: 'Spending by category. Exact MYR values follow.',
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
            for (final item in report.categories)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  categoryIcons[item.iconKey] ?? Icons.more_horiz,
                  color: categoryColor(item.colorHex),
                ),
                title: Text(item.name),
                subtitle: Text(
                  '${item.amount.format()} · ${item.count} transactions',
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
  const CashFlowTrend({required this.report, this.title, super.key});
  final FinancialReport report;
  final String? title;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maximum = report.buckets.fold<int>(
      0,
      (value, bucket) =>
          math.max(value, math.max(bucket.incomeMinor, bucket.expenseMinor)),
    );
    String label(TrendBucket bucket) =>
        report.period.isYear ? monthLabel(bucket.date) : dayLabel(bucket.date);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title ??
                  (report.period.isYear
                      ? 'Monthly cash flow'
                      : 'Daily cash flow'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text('MYR · Exact values below'),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Legend(color: colors.primary, label: 'Income'),
                _Legend(color: colors.error, label: 'Expenses'),
              ],
            ),
            if (maximum == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No MYR cash flow to chart in this period.'),
              )
            else
              Semantics(
                label:
                    'Income and expense trends in MYR. Exact values are available below.',
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 240,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: BarChart(
                        BarChartData(
                          minY: 0,
                          maxY: maximum.toDouble() / 100 * 1.15,
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
                                      index % (report.period.isYear ? 3 : 7) !=
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
                                    toY:
                                        report.buckets[index].incomeMinor
                                            .toDouble() /
                                        100,
                                    color: colors.primary,
                                    width: report.period.isYear ? 7 : 3,
                                  ),
                                  BarChartRodData(
                                    toY:
                                        report.buckets[index].expenseMinor
                                            .toDouble() /
                                        100,
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
                      'Income: ${_myr(bucket.incomeMinor)}\nExpenses: ${_myr(bucket.expenseMinor)}',
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

String _myr(int value) => Money.fromMinor(
  minorUnits: value,
  currencyCode: 'MYR',
  decimalPlaces: 2,
).format();

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
