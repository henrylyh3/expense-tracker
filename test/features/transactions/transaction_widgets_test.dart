import 'package:expense_tracker/core/dates/calendar_date.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/core/money/money.dart';
import 'package:expense_tracker/core/money/display_currency.dart';
import 'package:expense_tracker/core/providers/default_currency_provider.dart';
import 'package:expense_tracker/features/categories/domain/ledger_category.dart';
import 'package:expense_tracker/features/categories/presentation/category_view_model.dart';
import 'package:expense_tracker/features/currencies/domain/configured_currency.dart';
import 'package:expense_tracker/features/currencies/presentation/currency_view_model.dart';
import 'package:expense_tracker/features/transactions/domain/conversion_policy.dart';
import 'package:expense_tracker/features/transactions/domain/ledger_transaction.dart';
import 'package:expense_tracker/features/transactions/presentation/transaction_editor_screen.dart';
import 'package:expense_tracker/features/transactions/presentation/transaction_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('new expense starts in the saved default currency', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(display: const DisplayCurrency('USD', 2, '4.7')),
    );
    await tester.pumpAndSettle();
    expect(find.text('USD · Dollar'), findsOneWidget);
    await tester.ensureVisible(_field('Amount'));
    await tester.enterText(_field('Amount'), '12.50');
    await tester.pumpAndSettle();
    expect(find.text('USD equivalent: USD 12.50'), findsOneWidget);
  });

  testWidgets('new MYR transaction previews its exact MYR amount', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.ensureVisible(_field('Amount'));
    await tester.enterText(_field('Amount'), '12.50');
    await tester.pumpAndSettle();
    expect(find.text('MYR equivalent: RM 12.50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit uses saved rate despite a changed currency default', (
    tester,
  ) async {
    await tester.pumpWidget(_app(edit: true));
    await tester.pumpAndSettle();
    expect(find.text('1 USD = 4.5 MYR'), findsOneWidget);
    await tester.ensureVisible(_field('Amount'));
    await tester.enterText(_field('Amount'), '20');
    await tester.pumpAndSettle();
    expect(find.text('MYR equivalent: RM 90.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('currency change cannot save before conversion confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(_app(edit: true));
    await tester.pumpAndSettle();
    final currency = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Currency',
    );
    await tester.ensureVisible(currency);
    await tester.pumpAndSettle();
    await tester.tap(currency);
    await tester.pumpAndSettle();
    await tester.tap(find.text('JPY · Yen').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(_field('Amount'));
    await tester.enterText(_field('Amount'), '500');
    await tester.pumpAndSettle();
    expect(find.text('MYR equivalent: RM 15.00'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text('Confirm the new currency and conversion before saving.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'original archived selections remain available for historical edits',
    (tester) async {
      await tester.pumpWidget(_app(edit: true, archived: true));
      await tester.pumpAndSettle();
      expect(find.text('Food (archived)'), findsOneWidget);
      expect(find.text('USD · Dollar (archived)'), findsOneWidget);
      expect(find.text('1 USD = 4.5 MYR'), findsOneWidget);
    },
  );
}

Widget _app({
  bool edit = false,
  bool archived = false,
  DisplayCurrency display = DisplayCurrency.myr,
}) => ProviderScope(
  overrides: [
    defaultCurrencyProvider.overrideWith((ref) => Stream.value(display)),
    categoriesProvider.overrideWith(
      (ref) => Stream.value([
        LedgerCategory(
          id: 'food',
          name: 'Food',
          type: TransactionType.expense,
          iconKey: 'restaurant',
          colorHex: '#123456',
          sortOrder: 0,
          isArchived: archived,
          usageCount: edit ? 1 : 0,
        ),
      ]),
    ),
    currenciesProvider.overrideWith(
      (ref) => Stream.value([
        const ConfiguredCurrency(
          code: 'MYR',
          name: 'Ringgit',
          symbol: 'RM',
          decimalPlaces: 2,
          rateToMyr: '1',
          isActive: true,
          usageCount: 0,
        ),
        ConfiguredCurrency(
          code: 'USD',
          name: 'Dollar',
          symbol: r'$',
          decimalPlaces: 2,
          rateToMyr: '4.7',
          isActive: !archived,
          usageCount: edit ? 1 : 0,
        ),
        const ConfiguredCurrency(
          code: 'JPY',
          name: 'Yen',
          symbol: '¥',
          decimalPlaces: 0,
          rateToMyr: '0.03',
          isActive: true,
          usageCount: 0,
        ),
      ]),
    ),
    if (edit)
      transactionProvider(
        'record',
      ).overrideWith((ref) => Stream.value(_record(archived))),
  ],
  child: MaterialApp(
    home: TransactionEditorScreen(transactionId: edit ? 'record' : null),
  ),
);

LedgerTransaction _record(bool archived) => LedgerTransaction(
  id: 'record',
  categoryId: 'food',
  categoryName: 'Food',
  categoryIconKey: 'restaurant',
  categoryColorHex: '#123456',
  categoryArchived: archived,
  currencyActive: !archived,
  type: TransactionType.expense,
  conversion: ConversionSnapshot(
    original: Money.parsePositive(
      '12.50',
      currencyCode: 'USD',
      decimalPlaces: 2,
    ),
    exchangeRate: '4.5',
    myr: Money.fromMinor(
      minorUnits: 5625,
      currencyCode: 'MYR',
      decimalPlaces: 2,
    ),
  ),
  date: CalendarDate.parse('2026-11-05'),
  note: null,
  createdAtUtc: 1,
  updatedAtUtc: 1,
);

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);
