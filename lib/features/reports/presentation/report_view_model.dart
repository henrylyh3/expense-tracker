import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../core/providers/default_currency_provider.dart';
import '../../../core/money/display_currency.dart';
import '../../currencies/presentation/currency_view_model.dart';
import '../../transactions/domain/ledger_transaction.dart';
import '../../transactions/domain/transaction_filter.dart';
import '../../transactions/presentation/transaction_view_model.dart';
import '../data/report_repository.dart';
import '../domain/financial_report.dart';
import '../domain/report_period.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(ref.watch(databaseProvider)),
);
final financialReportProvider = StreamProvider.autoDispose
    .family<FinancialReport, ReportPeriod>(
      (ref, period) => ref
          .watch(reportRepositoryProvider)
          .watchPeriod(
            period,
            expensesOnly: true,
            tripId:
                ref.watch(activeTripProvider).asData?.value ?? personalTripId,
          ),
      retry: (count, error) => null,
    );
final dashboardRecentProvider = StreamProvider.autoDispose
    .family<List<LedgerTransaction>, ReportPeriod>(
      (ref, period) => ref
          .watch(transactionRepositoryProvider)
          .watchHistory(
            limit: 5,
            tripId:
                ref.watch(activeTripProvider).asData?.value ?? personalTripId,
            filter: const TransactionFilter.empty().expensesOnly,
          ),
      retry: (count, error) => null,
    );

final reportCurrencyChoiceProvider =
    NotifierProvider<ReportCurrencyChoice, String?>(ReportCurrencyChoice.new);

class ReportCurrencyChoice extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(activeTripProvider);
    return null;
  }

  void select(String? code) => state = code;
}

final reportDisplayCurrencyProvider = Provider<DisplayCurrency>((ref) {
  final fallback =
      ref.watch(defaultCurrencyProvider).asData?.value ?? DisplayCurrency.myr;
  final code = ref.watch(reportCurrencyChoiceProvider);
  if (code == null) return fallback;
  final currencies = ref.watch(currenciesProvider).asData?.value ?? [];
  final item = currencies
      .where((currency) => currency.isActive && currency.code == code)
      .firstOrNull;
  if (item == null) return fallback;
  final trip = ref.watch(activeTripProvider).asData?.value ?? personalTripId;
  final rate =
      ref.watch(tripRatesProvider(trip)).asData?.value[code]?.rate ??
      item.rateToMyr;
  return DisplayCurrency(code, item.decimalPlaces, rate);
});
