import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/features/categories/domain/ledger_category.dart';
import 'package:expense_tracker/features/categories/presentation/categories_screen.dart';
import 'package:expense_tracker/features/categories/presentation/category_view_model.dart';
import 'package:expense_tracker/features/currencies/domain/configured_currency.dart';
import 'package:expense_tracker/features/currencies/presentation/currency_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'category filters hide archives and separate income from expenses',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
                  usageCount: 1,
                ),
                LedgerCategory(
                  id: 'old',
                  name: 'Old category',
                  type: TransactionType.expense,
                  iconKey: 'more_horiz',
                  colorHex: '#123456',
                  sortOrder: 1,
                  isArchived: true,
                  usageCount: 1,
                ),
                LedgerCategory(
                  id: 'salary',
                  name: 'Salary',
                  type: TransactionType.income,
                  iconKey: 'payments',
                  colorHex: '#123456',
                  sortOrder: 2,
                  isArchived: false,
                  usageCount: 0,
                ),
              ]),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: CategoriesScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Old category'), findsNothing);
      expect(find.text('Salary'), findsNothing);
      await tester.tap(find.text('Show archived'));
      await tester.pumpAndSettle();
      expect(find.text('Old category'), findsOneWidget);
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Food'), findsNothing);
    },
  );

  testWidgets(
    'JPY template selects precision zero and leaves rate for manual entry',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CurrencyEditor(configuredCodes: {'MYR'})),
          ),
        ),
      );
      await tester.tap(find.text('Currency template (optional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JPY · Japanese Yen').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_field('Currency code')).controller!.text,
        'JPY',
      );
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              find.byType(DropdownButtonFormField<int>),
            )
            .initialValue,
        0,
      );
      expect(
        tester.widget<TextField>(_field('MYR for 1 JPY')).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('MYR identity fields are read-only but metadata is editable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CurrencyEditor(
              configuredCodes: {'MYR'},
              currency: ConfiguredCurrency(
                code: 'MYR',
                name: 'Ringgit',
                symbol: 'RM',
                decimalPlaces: 2,
                rateToMyr: '1',
                isActive: true,
                usageCount: 0,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.widget<TextField>(_field('Currency code')).readOnly, isTrue);
    expect(tester.widget<TextField>(_field('MYR for 1 MYR')).readOnly, isTrue);
    expect(tester.widget<TextField>(_field('Currency name')).readOnly, isFalse);
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .onChanged,
      isNull,
    );
  });
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);
