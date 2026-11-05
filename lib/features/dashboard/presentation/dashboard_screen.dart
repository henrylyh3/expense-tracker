import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/ledger_types.dart';
import '../../../shared/widgets/management_widgets.dart';
import '../../reports/domain/report_period.dart';
import '../../reports/presentation/report_view_model.dart';
import '../../reports/presentation/report_widgets.dart';
import '../../transactions/domain/transaction_filter.dart';
import '../../transactions/presentation/transaction_view_model.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(dashboardPeriodProvider);
    final report = ref.watch(financialReportProvider(period));
    final year = ReportPeriod.year(period.year);
    final annual = ref.watch(financialReportProvider(year));
    final recent = ref.watch(dashboardRecentProvider(period));
    void history({String? category}) {
      ref
          .read(historyFilterProvider.notifier)
          .set(
            TransactionFilter(
              from: period.start,
              to: period.lastDay,
              categoryId: category,
              type: category == null ? null : TransactionType.expense,
            ),
          );
      context.go('/history');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        Text(
          'Your private ledger',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        PeriodControl(
          period: period,
          onMove: ref.read(dashboardPeriodProvider.notifier).move,
          onToday: ref.read(dashboardPeriodProvider.notifier).today,
        ),
        const SizedBox(height: 16),
        report.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => ManagementLoadError(
            message: error is LedgerException
                ? error.message
                : 'Unable to load this month.',
            onRetry: () => ref.invalidate(financialReportProvider(period)),
          ),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FinancialSummary(report: value),
              const SizedBox(height: 16),
              SpendingBreakdown(
                report: value,
                onCategory: (category) => history(category: category.id),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        annual.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ManagementLoadError(
            message: error is LedgerException
                ? error.message
                : 'Unable to load monthly trends.',
            onRetry: () => ref.invalidate(financialReportProvider(year)),
          ),
          data: (value) => CashFlowTrend(
            report: value,
            title: 'Monthly cash flow · ${period.year}',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Recent transactions · ${periodLabel(period)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        TextButton(
          onPressed: () => history(),
          child: const Text('View period history'),
        ),
        recent.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ManagementLoadError(
            message: 'Unable to load recent transactions.',
            onRetry: () => ref.invalidate(dashboardRecentProvider(period)),
          ),
          data: (items) => items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No transactions in this month.'),
                )
              : Column(
                  children: [
                    for (final item in items.take(5))
                      Card(
                        child: ListTile(
                          title: Text(item.categoryName),
                          subtitle: Text(
                            '${item.date} · ${item.type.name}\n${item.conversion.myr.format()}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/transactions/${item.id}'),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
