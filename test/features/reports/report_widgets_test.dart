import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/features/reports/domain/financial_report.dart';
import 'package:expense_tracker/features/reports/presentation/report_view_model.dart';
import 'package:expense_tracker/features/reports/presentation/reports_screen.dart';
import 'package:expense_tracker/features/transactions/domain/transaction_filter.dart';
import 'package:expense_tracker/features/transactions/presentation/transaction_view_model.dart';
import 'package:expense_tracker/features/transactions/presentation/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'report displays the active trip without month or year controls',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financialReportProvider.overrideWith(
              (ref, period) =>
                  Stream.value(FinancialReport.calculate(period, const [])),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: ReportsScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Yearly'), findsNothing);
      expect(find.text('Monthly'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'category drill-down opens history with category and no date constraints',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/reports',
        routes: [
          GoRoute(
            path: '/reports',
            builder: (context, state) => const Scaffold(body: ReportsScreen()),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) =>
                const Scaffold(body: TransactionsScreen()),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsProvider.overrideWith((ref) => Stream.value(const [])),
            financialReportProvider.overrideWith(
              (ref, period) => Stream.value(
                FinancialReport.calculate(period, [
                  ReportEntry(
                    type: TransactionType.expense,
                    amountMyrMinor: 5625,
                    date: period.start,
                    categoryId: 'food',
                    categoryName: 'Food',
                    categoryColorHex: '#123456',
                    categoryIconKey: 'restaurant',
                  ),
                ]),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final category = find.text('Food').last;
      await tester.ensureVisible(category);
      await tester.pumpAndSettle();
      await tester.tap(category);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TransactionsScreen)),
      );
      final filter = container.read(historyFilterProvider);
      expect(filter.categoryId, 'food');
      expect(filter.type, isNull);
      expect(filter.from, isNull);
      expect(filter.to, isNull);
      expect(find.text('No transactions match these filters.'), findsOneWidget);
    },
  );

  testWidgets('clearing filters cancels a pending debounced search', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyFilterProvider.overrideWith(_FilteredHistory.new),
          transactionsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: Scaffold(body: TransactionsScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pending search');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Clear all'));
    await tester.pump(const Duration(milliseconds: 500));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TransactionsScreen)),
    );
    expect(
      container.read(historyFilterProvider),
      const TransactionFilter.empty(),
    );
    expect(
      find.text('No transactions yet. Add your first expense.'),
      findsOneWidget,
    );
  });
}

class _FilteredHistory extends HistoryFilter {
  @override
  TransactionFilter build() =>
      TransactionFilter(query: 'Lunch', currencyCode: 'USD');
}
