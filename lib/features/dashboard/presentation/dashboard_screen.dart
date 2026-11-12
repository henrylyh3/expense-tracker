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
    final trips = ref.watch(tripsProvider).asData?.value ?? [];
    final used =
        ref.watch(tripUsedCurrenciesProvider(active)).asData?.value ??
        const <String>{};
    final options =
        ref
            .watch(currenciesProvider)
            .asData
            ?.value
            .where((item) => used.contains(item.code))
            .toList() ??
        [];
    final codes = options.map((item) => item.key).toList();
    final period = ReportPeriod.trip();
    final report = ref.watch(financialReportProvider(period));
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
                key: const ValueKey('home-currency'),
                isExpanded: true,
                value: codes.contains(display.key) ? display.key : null,
                hint: Text(display.code),
                menuWidth: 260,
                selectedItemBuilder: (context) => [
                  for (final item in options)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(item.code),
                    ),
                ],
                items: [
                  for (final item in options)
                    DropdownMenuItem(
                      value: item.key,
                      child: Text(
                        '${item.code} · ${item.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: codes.isEmpty
                    ? null
                    : ref.read(reportCurrencyChoiceProvider.notifier).select,
              ),
            ),
          ],
        ),
        Semantics(
          label: 'Active profile',
          child: DropdownButton<String>(
            key: const ValueKey('home-profile'),
            value: trips.any((trip) => trip.id == active) ? active : null,
            hint: const Text('Profile'),
            isExpanded: true,
            items: [
              for (final trip in trips)
                DropdownMenuItem(
                  value: trip.id,
                  child: Text(trip.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: trips.isEmpty
                ? null
                : (id) async {
                    if (id == null || id == active) return;
                    try {
                      await ref.read(tripActionsProvider).activate(id);
                    } catch (error) {
                      if (context.mounted) {
                        showManagementMessage(
                          context,
                          ledgerErrorMessage(error),
                        );
                      }
                    }
                  },
          ),
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
      ],
    );
  }
}
