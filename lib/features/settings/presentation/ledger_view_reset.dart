import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/appearance_provider.dart';
import '../../../core/providers/ledger_operation_providers.dart';
import '../../categories/presentation/category_view_model.dart';
import '../../currencies/presentation/currency_view_model.dart';
import '../../reports/presentation/report_view_model.dart';
import '../../transactions/presentation/transaction_view_model.dart';

/// Drop selections/actions/forms belonging to a ledger that has been replaced.
/// The caller has already committed the restore or active-file switch.
void resetLedgerViews(Ref ref) {
  ref.invalidate(historyFilterProvider);
  ref.invalidate(historyLimitProvider);
  ref.invalidate(dashboardPeriodProvider);
  ref.invalidate(reportPeriodProvider);
  ref.invalidate(categoryActionsProvider);
  ref.invalidate(currencyActionsProvider);
  ref.invalidate(transactionActionsProvider);
  ref.invalidate(appearanceActionsProvider);
  ref.read(ledgerResetSignalProvider.notifier).restored();
}
