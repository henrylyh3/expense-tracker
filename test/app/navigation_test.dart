import 'package:expense_tracker/app/router.dart';
import 'package:expense_tracker/core/providers/database_providers.dart';
import 'package:expense_tracker/app/theme.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/core/money/money.dart';
import 'package:expense_tracker/core/dates/calendar_date.dart';
import 'package:expense_tracker/core/money/display_currency.dart';
import 'package:expense_tracker/core/providers/default_currency_provider.dart';
import 'package:expense_tracker/core/providers/trip_provider.dart';
import 'package:expense_tracker/features/categories/domain/ledger_category.dart';
import 'package:expense_tracker/features/categories/presentation/category_view_model.dart';
import 'package:expense_tracker/features/currencies/domain/configured_currency.dart';
import 'package:expense_tracker/features/currencies/presentation/currency_view_model.dart';
import 'package:expense_tracker/features/reports/presentation/report_view_model.dart';
import 'package:expense_tracker/features/transactions/presentation/transaction_view_model.dart';
import 'package:expense_tracker/features/transactions/domain/transaction_input.dart';
import 'package:expense_tracker/features/transactions/domain/ledger_transaction.dart';
import 'package:expense_tracker/features/transactions/domain/conversion_policy.dart';
import 'package:expense_tracker/features/settings/presentation/trips_screen.dart';
import 'package:expense_tracker/features/reports/domain/financial_report.dart';
import 'package:expense_tracker/features/reports/domain/report_period.dart';
import 'package:expense_tracker/features/sharing/presentation/sharing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/report_overrides.dart';

void main() {
  testWidgets(
    'Home and History show date and amount without an expense label',
    (tester) async {
      final money = Money.parsePositive(
        '12.50',
        currencyCode: 'MYR',
        decimalPlaces: 2,
      );
      final item = LedgerTransaction(
        id: 'history-item',
        categoryId: 'food',
        categoryName: 'Food',
        categoryIconKey: 'restaurant',
        categoryColorHex: '#123456',
        categoryArchived: false,
        currencyActive: true,
        type: TransactionType.expense,
        conversion: ConversionSnapshot(
          original: money,
          exchangeRate: '1',
          myr: money,
        ),
        date: CalendarDate.parse('2026-11-09'),
        note: null,
        createdAtUtc: 1,
        updatedAtUtc: 1,
      );
      await tester.pumpWidget(_navigationApp(history: [item]));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('2026-11-09\nRM 12.50'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('2026-11-09\nRM 12.50'), findsOneWidget);
      expect(find.textContaining('· expense'), findsNothing);
      expect(find.textContaining('Â'), findsNothing);
      await tester.tap(find.text('History').last);
      await tester.pumpAndSettle();
      expect(find.text('2026-11-09\nRM 12.50'), findsOneWidget);
      expect(find.textContaining('· expense'), findsNothing);
      expect(find.textContaining('−RM'), findsNothing);
    },
  );
  testWidgets(
    'trip summary shows original currency totals and a fixed MYR total on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final report = FinancialReport.calculate(ReportPeriod.trip(), [
        for (final item in [
          ('USD', '10.00', 4500, '4.5'),
          ('USD', '2.00', 1000, '5'),
          ('MYR', '3.00', 300, '1'),
        ])
          ReportEntry(
            type: TransactionType.expense,
            amountMyrMinor: item.$3,
            exchangeRate: item.$4,
            original: Money.parsePositive(
              item.$2,
              currencyCode: item.$1,
              decimalPlaces: 2,
            ),
            date: CalendarDate.parse('2026-11-09'),
            categoryId: 'food',
            categoryName: 'Food',
            categoryColorHex: '#123456',
            categoryIconKey: 'restaurant',
          ),
      ]);
      await tester.pumpWidget(_navigationApp(tripReport: report, textScale: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Trips and profiles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trips and profiles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();
      expect(find.text('Spent by currency'), findsOneWidget);
      expect(find.text('USD 12.00'), findsOneWidget);
      expect(find.text('1 USD = 4.5 MYR'), findsOneWidget);
      expect(find.text('1 USD = 5 MYR'), findsOneWidget);
      expect(find.text('RM 3.00'), findsOneWidget);
      await tester.ensureVisible(find.text('Total in MYR'));
      await tester.pumpAndSettle();
      expect(find.text('RM 58.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(DropdownButton<String>), findsNothing);
      await tester.ensureVisible(find.text('Expenses by category'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shared trips opens in Settings and joining can be cancelled', (
    tester,
  ) async {
    await tester.pumpWidget(_navigationApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shared trips'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Shared trips'), findsOneWidget);
    expect(find.text('Start hosting'), findsNothing);
    expect(find.text('Configure internet sharing'), findsOneWidget);
    await tester.tap(find.text('Join using invitation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Paste invitation'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Configure internet sharing'), findsOneWidget);
  });
  testWidgets('Home report currency does not change the expense default', (
    tester,
  ) async {
    await tester.pumpWidget(_navigationApp());
    await tester.pumpAndSettle();
    final dropdown = find.byType(DropdownButton<String>);
    expect(tester.widget<DropdownButton<String>>(dropdown).value, 'MYR');
    expect(
      tester
          .widget<DropdownButton<String>>(dropdown)
          .items!
          .map((item) => item.value),
      ['MYR', 'USD'],
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD · US Dollar').last);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(dropdown));
    expect(container.read(reportDisplayCurrencyProvider).code, 'USD');
    expect(container.read(defaultCurrencyProvider).requireValue.code, 'MYR');
    expect(find.text('0 expenses · Displayed in USD'), findsOneWidget);
  });

  testWidgets('hides Add in Settings and returns to History after saving', (
    tester,
  ) async {
    await tester.pumpWidget(_navigationApp());
    await tester.pumpAndSettle();
    expect(find.text('Your private ledger'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Transaction history'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Understand your spending'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Manage currencies'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Add transaction'),
    );
    await tester.pumpAndSettle();
    final category = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Category',
    );
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    final amount = find.widgetWithText(TextFormField, 'Amount');
    await tester.ensureVisible(amount);
    await tester.enterText(amount, '12.50');
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Expense saved'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trip pages share Settings navigation and one app bar', (
    tester,
  ) async {
    await tester.pumpWidget(_navigationApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trips and profiles'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Trips and profiles'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Personal'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Expenses by category'), findsOneWidget);
    expect(find.text('Daily expenses'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Trips and profiles'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Currency settings'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Trip currencies'), findsOneWidget);
    expect(find.text('Default expense currency for this trip'), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('Manage currencies'), findsOneWidget);
  });

  testWidgets('preserves the settings stack across tabs and supports Back', (
    tester,
  ) async {
    await tester.pumpWidget(_navigationApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage currencies'));
    await tester.pumpAndSettle();

    expect(find.text('Add currency'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Your private ledger'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Add currency'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Manage currencies'), findsOneWidget);
    expect(find.text('Add currency'), findsNothing);
  });

  testWidgets('supports a narrow screen and enlarged text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_navigationApp(textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Widget _navigationApp({
  double textScale = 1,
  FinancialReport? tripReport,
  List<LedgerTransaction> history = const [],
}) => ProviderScope(
  overrides: [
    databaseReadyProvider.overrideWith((ref) async {}),
    sharedSessionsProvider.overrideWith((ref) => Stream.value(const [])),
    activeTripProvider.overrideWith((ref) => Stream.value(personalTripId)),
    tripsProvider.overrideWith(
      (ref) => Stream.value([(id: personalTripId, name: 'Personal')]),
    ),
    tripRatesProvider.overrideWith((ref, id) => Stream.value(const {})),
    tripUsedCurrenciesProvider.overrideWith(
      (ref, id) => Stream.value({'MYR', 'USD'}),
    ),
    globalDefaultCurrencyProvider.overrideWith(
      (ref) => Stream.value(DisplayCurrency.myr),
    ),
    tripSummaryProvider.overrideWith(
      (ref, id) => Stream.value(
        tripReport ?? FinancialReport.calculate(ReportPeriod.trip(), const []),
      ),
    ),
    defaultCurrencyProvider.overrideWith(
      (ref) => Stream.value(DisplayCurrency.myr),
    ),
    ...emptyReportOverrides(recent: history),
    transactionsProvider.overrideWith((ref) => Stream.value(history)),
    categoriesProvider.overrideWith(
      (ref) => Stream.value(const [
        LedgerCategory(
          id: 'food',
          name: 'Food',
          type: TransactionType.expense,
          iconKey: 'restaurant',
          colorHex: '#123456',
          sortOrder: 0,
          isArchived: false,
          usageCount: 0,
        ),
      ]),
    ),
    transactionActionsProvider.overrideWith(_TestTransactionActions.new),
    currenciesProvider.overrideWith(
      (ref) => Stream.value(const [
        ConfiguredCurrency(
          code: 'MYR',
          name: 'Malaysian Ringgit',
          symbol: 'RM',
          decimalPlaces: 2,
          rateToMyr: '1',
          isActive: true,
          usageCount: 0,
        ),
        ConfiguredCurrency(
          code: 'USD',
          name: 'US Dollar',
          symbol: r'$',
          decimalPlaces: 2,
          rateToMyr: '4.5',
          isActive: true,
          usageCount: 0,
        ),
      ]),
    ),
  ],
  child: Consumer(
    builder: (context, ref, child) => MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  ),
);

class _TestTransactionActions extends TransactionActions {
  @override
  Future<String?> save(
    TransactionInput input, {
    String? id,
    int? expectedUpdatedAtUtc,
  }) async {
    expect(input.type, TransactionType.expense);
    return 'saved-expense';
  }
}
