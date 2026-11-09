import 'package:expense_tracker/core/money/currency_catalog.dart';
import 'package:expense_tracker/core/dates/calendar_date.dart';
import 'package:expense_tracker/features/currencies/data/frankfurter_service.dart';
import 'package:expense_tracker/features/currencies/domain/configured_currency.dart';
import 'package:expense_tracker/features/currencies/presentation/currency_view_model.dart';
import 'package:expense_tracker/features/currencies/presentation/currency_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'adding a named record retains a legacy configured currency scale',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyActionsProvider.overrideWith(_CaptureActions.new),
            frankfurterServiceProvider.overrideWithValue(_Quote()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CurrencyEditor(
                configuredCodes: {'MYR', 'JPY'},
                configuredPrecisions: {'JPY': 2},
              ),
            ),
          ),
        ),
      );
      Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.enterText(field('Currency code'), 'JPY');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.enterText(field('Currency name'), 'Yen 2026');
      await tester.enterText(field('Symbol'), 'JPY');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CurrencyEditor)),
      );
      expect(
        (container.read(currencyActionsProvider.notifier) as _CaptureActions)
            .captured
            ?.decimalPlaces,
        2,
      );
    },
  );
  test('offline catalogue covers current monetary codes in code order', () {
    expect(currencyCatalog.length, 165);
    final codes = currencyCatalog.map((c) => c.code).toList();
    expect(codes.toSet().length, codes.length);
    expect(codes, [...codes]..sort());
    expect(
      codes,
      containsAll([
        'AED',
        'AUD',
        'CAD',
        'CHF',
        'JPY',
        'KWD',
        'MYR',
        'USD',
        'ZWG',
      ]),
    );
    for (final item in currencyCatalog) {
      expect(item.name.length, inInclusiveRange(1, 80));
      expect(item.symbol.runes.length, inInclusiveRange(1, 12));
    }
  });
  testWidgets('search accepts code or name and keeps code sorting', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: CurrencyEditor(configuredCodes: {'MYR'})),
        ),
      ),
    );
    final search = find.descendant(
      of: find.byKey(const ValueKey('currency-template-search')),
      matching: find.byType(TextField),
    );
    await tester.tap(search);
    await tester.enterText(search, 'dollar');
    await tester.pumpAndSettle();
    final menu = tester.widget<DropdownMenu<String>>(
      find.byType(DropdownMenu<String>),
    );
    final filtered = menu.filterCallback!(menu.dropdownMenuEntries, 'dollar');
    final codes = filtered.map((e) => e.value).toList();
    expect(codes, containsAll(['AUD', 'CAD', 'USD']));
    expect(codes, [...codes]..sort());
    await tester.enterText(search, '  kwd ');
    await tester.pumpAndSettle();
    expect(find.text('KWD · Kuwaiti Dinar'), findsWidgets);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('duplicate currency name is reported in the form', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CurrencyEditor(
              configuredCodes: {'MYR'},
              existingNames: {'THB': 'THB 2025'},
            ),
          ),
        ),
      ),
    );
    final name = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Currency name',
    );
    await tester.enterText(name, ' thb   2025 ');
    await tester.pumpAndSettle();
    expect(
      find.text('This currency name is already used. Choose another name.'),
      findsOneWidget,
    );
  });
}

class _CaptureActions extends CurrencyActions {
  CurrencyDraft? captured;
  @override
  Future<bool> save(CurrencyDraft draft, {String? originalCode}) async {
    captured = draft;
    return false;
  }
}

class _Quote extends FrankfurterService {
  @override
  Future<FrankfurterQuote> fetch(String code) async =>
      FrankfurterQuote(rate: '0.03', date: CalendarDate.parse('2026-11-09'));
}
