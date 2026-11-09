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
  testWidgets(
    'named records mark app and trip defaults separately and update live',
    (tester) async {
      final defaults = StreamController<DisplayCurrency>();
      addTearDown(defaults.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            globalDefaultCurrencyProvider.overrideWith(
              (ref) => defaults.stream,
            ),
            defaultCurrencyProvider.overrideWith(
              (ref) => Stream.value(
                const DisplayCurrency('THB', 2, '0.13', recordId: 'thb-2026'),
              ),
            ),
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
      defaults.add(
        const DisplayCurrency('THB', 2, '0.13', recordId: 'thb-2025'),
      );
      await tester.pumpAndSettle();
      final appDefault = find.ancestor(
        of: find.textContaining('App default'),
        matching: find.byType(ListTile),
      );
      final tripDefault = find.ancestor(
        of: find.textContaining('Current trip default'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: appDefault, matching: find.text('THB 2025 (฿)')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tripDefault, matching: find.text('THB 2026 (฿)')),
        findsOneWidget,
      );
      defaults.add(
        const DisplayCurrency('THB', 2, '0.13', recordId: 'thb-2026'),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('App default · Current trip default'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
