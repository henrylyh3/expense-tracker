import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/trip_provider.dart';
import '../../currencies/presentation/currency_view_model.dart';
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
    final display = ref.watch(reportDisplayCurrencyProvider);
    final active =
        ref.watch(activeTripProvider).asData?.value ?? personalTripId;
    final trip = ref
        .watch(tripsProvider)
        .asData
        ?.value
        .where((item) => item.id == active)
        .firstOrNull;
    final used =
        ref.watch(tripUsedCurrenciesProvider(active)).asData?.value ??
        const <String>{};
    final codes =
        ref
            .watch(currenciesProvider)
            .asData
            ?.value
            .where((item) => used.contains(item.code))
            .map((item) => item.code)
            .toList() ??
        [];
    final period = ReportPeriod.trip();
    final report = ref.watch(financialReportProvider(period));
    final recent = ref.watch(dashboardRecentProvider(period));
    void history({String? category}) {
      ref
          .read(historyFilterProvider.notifier)
          .set(TransactionFilter(categoryId: category));
      context.go('/history');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Your private ledger',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 88,
              child: DropdownButton<String>(
                isExpanded: true,
                value: codes.contains(display.code) ? display.code : null,
                hint: Text(display.code),
                items: [
                  for (final code in codes)
                    DropdownMenuItem(value: code, child: Text(code)),
                ],
                onChanged: codes.isEmpty
                    ? null
                    : ref.read(reportCurrencyChoiceProvider.notifier).select,
              ),
            ),
          ],
        ),
        Text(
          trip?.name ?? 'Personal',
          style: Theme.of(context).textTheme.titleMedium,
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
                : 'Unable to load this trip.',
            onRetry: () => ref.invalidate(financialReportProvider(period)),
          ),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FinancialSummary(report: value, currency: display),
              const SizedBox(height: 16),
              SpendingBreakdown(
                currency: display,
                report: value,
                onCategory: (category) => history(category: category.id),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        report.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ManagementLoadError(
            message: error is LedgerException
                ? error.message
                : 'Unable to load trip trends.',
            onRetry: () => ref.invalidate(financialReportProvider(period)),
          ),
          data: (value) => CashFlowTrend(
            report: value,
            currency: display,
            title: 'Trip spending by day',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Recent transactions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        TextButton(
          onPressed: () => history(),
          child: const Text('View trip history'),
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
                  child: Text('No transactions in this trip.'),
                )
              : Column(
                  children: [
                    for (final item in items.take(5))
                      Card(
                        child: ListTile(
                          title: Text(item.categoryName),
                          subtitle: Text(
                            '${item.date} · ${item.type.name}\n${display.format(item.conversion.myr.minorUnits)}',
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
