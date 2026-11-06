import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:expense_tracker/app/app.dart';
import 'package:expense_tracker/core/backup/backup_files.dart';
import 'package:expense_tracker/core/backup/backup_validator.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/providers/database_providers.dart';
import 'package:expense_tracker/core/providers/ledger_operation_providers.dart';
import 'package:expense_tracker/features/settings/presentation/backup_screen.dart';
import 'package:expense_tracker/features/settings/presentation/backup_view_model.dart';
import 'package:expense_tracker/features/transactions/domain/transaction_filter.dart';
import 'package:expense_tracker/features/transactions/presentation/transaction_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/backup_fixture.dart';

void main() {
  testWidgets(
    'real restore locks navigation then resets forms, filters, reports and theme',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(db.initialize);
      final files = _MemoryFiles();
      addTearDown(() {
        if (!files.releaseSafety.isCompleted) {
          files.releaseSafety.complete(false);
        }
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            backupFilesProvider.overrideWithValue(files),
          ],
          child: const ExpenseTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Backup and restore'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BackupScreen)),
      );
      container
          .read(historyFilterProvider.notifier)
          .set(TransactionFilter(query: 'old search', categoryId: 'seed-food'));
      await tester.runAsync(
        container.read(backupActionsProvider.notifier).chooseBackup,
      );
      await tester.pumpAndSettle();
      // Start real I/O in runAsync. The dialog's acknowledgment and safety
      // defaults are exercised separately in backup_widgets_test.dart.
      late Future<void> restoring;
      await tester.runAsync(() async {
        restoring = container
            .read(backupActionsProvider.notifier)
            .restore(safetyBackup: true);
        await _pumpUntil(tester, () => files.safetyStarted.isCompleted);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(ledgerTransferBusyProvider), isTrue);
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .onDestinationSelected,
        isNull,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(
        BackupValidator.decode(files.safetyBytes!).count('categories'),
        10,
      );
      await tester.runAsync(() async {
        files.releaseSafety.complete(true);
        await _pumpUntil(
          tester,
          () =>
              container.read(ledgerResetSignalProvider) == 1 &&
              !container.read(ledgerTransferBusyProvider),
        );
        await restoring;
      });
      await tester.pumpAndSettle();
      expect(find.byType(BackupScreen), findsNothing);
      expect(find.text('Your private ledger'), findsOneWidget);
      expect(container.read(ledgerTransferBusyProvider), isFalse);
      expect(
        container.read(historyFilterProvider),
        const TransactionFilter.empty(),
      );
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(
        (await db
                .customSelect('SELECT amount_myr_minor FROM transactions')
                .getSingle())
            .read<int>('amount_myr_minor'),
        5625,
      );
      expect(tester.takeException(), isNull);
      // Cancel real Drift subscriptions while the fake scheduler can still
      // drain its deferred query-cache cleanup before test teardown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

// Widget FakeAsync work and native/worker-isolate I/O must both make progress.
// Do not await real I/O while leaving the widget's fake scheduler unpumped.
Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Restore UI did not finish.');
    }
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _MemoryFiles extends BackupFiles {
  final safetyStarted = Completer<void>();
  final releaseSafety = Completer<bool>();
  Uint8List? safetyBytes;
  @override
  Future<Uint8List?> pick() async =>
      BackupValidator.fromDocument(backupDocument()).encode();
  @override
  Future<bool> save(Uint8List bytes, {bool safety = false}) async {
    safetyBytes = bytes;
    safetyStarted.complete();
    return releaseSafety.future;
  }
}
