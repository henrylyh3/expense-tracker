import 'package:expense_tracker/app/router.dart';
import 'package:expense_tracker/core/providers/database_providers.dart';
import 'package:expense_tracker/app/theme.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/features/categories/domain/ledger_category.dart';
import 'package:expense_tracker/features/categories/presentation/category_view_model.dart';
import 'package:expense_tracker/features/currencies/domain/configured_currency.dart';
import 'package:expense_tracker/features/currencies/presentation/currency_view_model.dart';
import 'package:expense_tracker/features/transactions/presentation/transaction_view_model.dart';
import 'package:expense_tracker/features/transactions/domain/transaction_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/report_overrides.dart';

void main() {
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
    expect(find.text('Transaction history'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

Widget _navigationApp({double textScale = 1}) => ProviderScope(
  overrides: [
    databaseReadyProvider.overrideWith((ref) async {}),
    ...emptyReportOverrides(),
    transactionsProvider.overrideWith((ref) => Stream.value(const [])),
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
