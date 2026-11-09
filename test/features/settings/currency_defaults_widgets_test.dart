import 'dart:async';

import 'package:expense_tracker/core/money/display_currency.dart';
import 'package:expense_tracker/core/providers/default_currency_provider.dart';
import 'package:expense_tracker/features/currencies/domain/configured_currency.dart';
import 'package:expense_tracker/features/currencies/presentation/currencies_screen.dart';
import 'package:expense_tracker/features/currencies/presentation/currency_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('named records show one default and update live', (tester) async {
    final defaults = StreamController<DisplayCurrency>();
    addTearDown(defaults.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          defaultCurrencyProvider.overrideWith((ref) => defaults.stream),
          currenciesProvider.overrideWith(
            (ref) => Stream.value([
              for (final year in [2025, 2026])
                ConfiguredCurrency(
                  code: 'THB',
                  name: 'THB $year',
                  symbol: '฿',
                  decimalPlaces: 2,
                  rateToMyr: '0.13',
                  isActive: true,
                  usageCount: 0,
                  recordId: 'thb-$year',
                ),
            ]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: CurrenciesScreen())),
      ),
    );
    defaults.add(const DisplayCurrency('THB', 2, '0.13', recordId: 'thb-2025'));
    await tester.pumpAndSettle();
    final selected = find.ancestor(
      of: find.textContaining('\nDefault'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: selected, matching: find.text('THB 2025 (฿)')),
      findsOneWidget,
    );
    expect(find.textContaining('App default'), findsNothing);
    expect(find.textContaining('Current trip default'), findsNothing);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Make default for current trip'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    defaults.add(const DisplayCurrency('THB', 2, '0.13', recordId: 'thb-2026'));
    await tester.pumpAndSettle();
    expect(find.textContaining('\nDefault'), findsOneWidget);
    expect(
      find.descendant(of: selected, matching: find.text('THB 2026 (฿)')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
