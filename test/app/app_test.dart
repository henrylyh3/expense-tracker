import 'dart:async';

import 'package:drift/native.dart';
import 'package:expense_tracker/app/app.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/providers/database_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/report_overrides.dart';

void main() {
  testWidgets(
    'real schema health failures stop startup without resetting the ledger',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(db.initialize);
      await db.customStatement('DROP TRIGGER protect_myr_delete');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...emptyReportOverrides(),
            databaseProvider.overrideWithValue(db),
          ],
          child: const ExpenseTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to open your ledger'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.textContaining('schema object'), findsNothing);
      expect(
        (await db
                .customSelect('SELECT count(*) AS n FROM categories')
                .getSingle())
            .read<int>('n'),
        10,
      );
      expect(
        await db
            .customSelect(
              "SELECT name FROM sqlite_schema WHERE type = 'trigger' AND name = 'protect_myr_delete'",
            )
            .get(),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('shows loading while the database initializes', (tester) async {
    final ready = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...emptyReportOverrides(),
          databaseReadyProvider.overrideWith((ref) => ready.future),
        ],
        child: const ExpenseTrackerApp(),
      ),
    );
    expect(find.text('Opening your ledger…'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    ready.complete();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('database errors expose Retry without showing internal details', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...emptyReportOverrides(),
          databaseReadyProvider.overrideWith((ref) async {
            if (attempts++ == 0) {
              throw StateError('/private/sensitive-ledger.sqlite');
            }
          }),
        ],
        child: const ExpenseTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to open your ledger'), findsOneWidget);
    expect(find.textContaining('/private/'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Your private ledger'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('retry shows loading until initialization finishes', (
    tester,
  ) async {
    final retry = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...emptyReportOverrides(),
          databaseReadyProvider.overrideWith((ref) {
            if (attempts++ == 0) {
              return Future<void>.error(StateError('Storage unavailable'));
            }
            return retry.future;
          }),
        ],
        child: const ExpenseTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Opening your ledger…'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    retry.complete();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(attempts, 2);
  });
}
