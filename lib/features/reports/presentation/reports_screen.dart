import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/ledger_types.dart';
import '../../../shared/widgets/management_widgets.dart';
import '../../transactions/domain/transaction_filter.dart';
import '../../transactions/presentation/transaction_view_model.dart';
import 'report_view_model.dart';
import 'report_widgets.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final report = ref.watch(financialReportProvider(period));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        Text(
          'Understand your spending',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        PeriodControl(
          period: period,
          onMove: ref.read(reportPeriodProvider.notifier).move,
          onToday: ref.read(reportPeriodProvider.notifier).today,
          onYearlyChanged: ref.read(reportPeriodProvider.notifier).yearly,
        ),
        const SizedBox(height: 16),
        report.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => ManagementLoadError(
            message: error is LedgerException
                ? error.message
                : 'Unable to load this report.',
            onRetry: () => ref.invalidate(financialReportProvider(period)),
          ),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FinancialSummary(report: value),
              const SizedBox(height: 16),
              CashFlowTrend(report: value),
              const SizedBox(height: 16),
              SpendingBreakdown(
                report: value,
                onCategory: (category) {
                  ref
                      .read(historyFilterProvider.notifier)
                      .set(
                        TransactionFilter(
                          categoryId: category.id,
                          from: period.start,
                          to: period.lastDay,
                        ),
                      );
                  context.go('/history');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
