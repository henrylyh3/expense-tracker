import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates/calendar_date.dart';
import '../../../core/providers/database_providers.dart';
import '../../transactions/domain/ledger_transaction.dart';
import '../../transactions/domain/transaction_filter.dart';
import '../../transactions/presentation/transaction_view_model.dart';
import '../data/report_repository.dart';
import '../domain/financial_report.dart';
import '../domain/report_period.dart';

class PeriodSelection extends Notifier<ReportPeriod> {
  int _lastMonth = CalendarDate.today().month;
  @override
  ReportPeriod build() {
    final today = CalendarDate.today();
    return ReportPeriod.month(today.year, today.month);
  }

  void move(int offset) {
    final next = state.shift(offset);
    if (next != null) {
      state = next;
      if (!next.isYear) _lastMonth = next.month!;
    }
  }

  void yearly(bool value) {
    if (value == state.isYear) return;
    if (value) {
      _lastMonth = state.month!;
      state = ReportPeriod.year(state.year);
    } else {
      state = ReportPeriod.month(state.year, _lastMonth);
    }
  }

  void today() {
    final now = CalendarDate.today();
    _lastMonth = now.month;
    state = state.isYear
        ? ReportPeriod.year(now.year)
        : ReportPeriod.month(now.year, now.month);
  }
}

final dashboardPeriodProvider = NotifierProvider<PeriodSelection, ReportPeriod>(
  PeriodSelection.new,
);
final reportPeriodProvider = NotifierProvider<PeriodSelection, ReportPeriod>(
  PeriodSelection.new,
);
final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(ref.watch(databaseProvider)),
);
final financialReportProvider = StreamProvider.autoDispose
    .family<FinancialReport, ReportPeriod>(
      (ref, period) => ref
          .watch(reportRepositoryProvider)
          .watchPeriod(period, expensesOnly: true),
      retry: (count, error) => null,
    );
final dashboardRecentProvider = StreamProvider.autoDispose
    .family<List<LedgerTransaction>, ReportPeriod>(
      (ref, period) => ref
          .watch(transactionRepositoryProvider)
          .watchHistory(
            limit: 5,
            filter: TransactionFilter(
              from: period.start,
              to: period.lastDay,
            ).expensesOnly,
          ),
      retry: (count, error) => null,
    );
