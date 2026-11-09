import 'dart:async';

import 'package:expense_tracker/core/dates/calendar_date.dart';
import 'package:expense_tracker/features/currencies/data/frankfurter_service.dart';
import 'package:expense_tracker/features/currencies/domain/configured_currency.dart';
import 'package:expense_tracker/features/currencies/presentation/currency_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Rates extends FrankfurterService {
  _Rates(this.reply);
  final Future<FrankfurterQuote> Function(String) reply;
  final calls = <String>[];
  @override
  Future<FrankfurterQuote> fetch(String code) {
    calls.add(code);
    return reply(code);
  }
}

final _date = CalendarDate.parse('2026-11-09');
FrankfurterQuote _quote(String rate) =>
    FrankfurterQuote(rate: rate, date: _date);
Finder _field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
String _value(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;
Widget _editor(_Rates rates, {ConfiguredCurrency? currency}) => ProviderScope(
  overrides: [frankfurterServiceProvider.overrideWithValue(rates)],
  child: MaterialApp(
    home: Scaffold(
      body: CurrencyEditor(configuredCodes: const {'MYR'}, currency: currency),
    ),
  ),
);

void main() {
  testWidgets(
    'new currency prefills once and remains editable without refresh',
    (tester) async {
      final rates = _Rates((_) async => _quote('0.121'));
      await tester.pumpWidget(_editor(rates));
      await tester.enterText(_field('Currency code'), 'THB');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(_value(tester, 'MYR for 1 THB'), '0.121');
      expect(
        find.textContaining('Frankfurter reference rate · 2026-11-09'),
        findsOneWidget,
      );
      await tester.enterText(_field('MYR for 1 THB'), '0.13');
      await tester.pump(const Duration(days: 1));
      expect(_value(tester, 'MYR for 1 THB'), '0.13');
      expect(rates.calls, ['THB']);
    },
  );
  testWidgets('a late quote never overwrites manual input', (tester) async {
    final pending = Completer<FrankfurterQuote>();
    final rates = _Rates((_) => pending.future);
    await tester.pumpWidget(_editor(rates));
    await tester.enterText(_field('Currency code'), 'USD');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(_field('MYR for 1 USD'), '4.9');
    pending.complete(_quote('4.5'));
    await tester.pumpAndSettle();
    expect(_value(tester, 'MYR for 1 USD'), '4.9');
    expect(find.textContaining('Frankfurter reference rate'), findsNothing);
  });
  testWidgets('switching currency ignores the earlier pending quote', (
    tester,
  ) async {
    final pending = Completer<FrankfurterQuote>();
    final rates = _Rates(
      (code) => code == 'USD' ? pending.future : Future.value(_quote('0.03')),
    );
    await tester.pumpWidget(_editor(rates));
    await tester.enterText(_field('Currency code'), 'USD');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(_field('Currency code'), 'JPY');
    await tester.pump(const Duration(milliseconds: 500));
    pending.complete(_quote('4.5'));
    await tester.pumpAndSettle();
    expect(_value(tester, 'MYR for 1 JPY'), '0.03');
  });
  testWidgets('saved currencies keep their rate and never trigger lookup', (
    tester,
  ) async {
    final rates = _Rates((_) async => _quote('0.121'));
    await tester.pumpWidget(
      _editor(
        rates,
        currency: const ConfiguredCurrency(
          recordId: 'thb-2025',
          code: 'THB',
          name: 'THB 2025',
          symbol: '฿',
          decimalPlaces: 2,
          rateToMyr: '0.13',
          isActive: true,
          usageCount: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_value(tester, 'MYR for 1 THB'), '0.13');
    expect(rates.calls, isEmpty);
  });
  testWidgets('an unavailable quote leaves manual rate entry available', (
    tester,
  ) async {
    final rates = _Rates((_) async => throw Exception('offline'));
    await tester.pumpWidget(_editor(rates));
    await tester.enterText(_field('Currency code'), 'THB');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not get a reference rate'),
      findsOneWidget,
    );
    await tester.enterText(_field('MYR for 1 THB'), '0.13');
    expect(_value(tester, 'MYR for 1 THB'), '0.13');
  });
}
