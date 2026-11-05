import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show LazyDatabase;
import 'package:drift/native.dart';
import 'package:expense_tracker/app/app.dart';
import 'package:expense_tracker/core/backup/backup_files.dart';
import 'package:expense_tracker/core/backup/backup_validator.dart';
import 'package:expense_tracker/core/backup/startup_recovery_service.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/database/ledger_storage.dart';
import 'package:expense_tracker/core/providers/database_providers.dart';
import 'package:expense_tracker/core/providers/ledger_operation_providers.dart';
import 'package:expense_tracker/features/settings/presentation/backup_view_model.dart';
import 'package:expense_tracker/features/settings/presentation/startup_recovery_screen.dart';
import 'package:expense_tracker/features/settings/presentation/startup_recovery_view_model.dart';
import 'package:expense_tracker/features/transactions/domain/transaction_filter.dart';
import 'package:expense_tracker/features/transactions/presentation/transaction_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_fixture.dart';
import '../../support/report_overrides.dart';

void main() {
  testWidgets(
    'failed startup offers a read-only preview and explicit confirmation on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final files = _Files();
      final service = _FakeService();
      final container = await _openFailed(tester, files, service);
      await tester.runAsync(
        container.read(startupRecoveryProvider.notifier).chooseBackup,
      );
      await tester.pumpAndSettle();
      expect(find.text('Validated recovery backup'), findsOneWidget);
      expect(service.calls, 0);
      final recover = find.text('Recover using this backup');
      await tester.ensureVisible(recover);
      await tester.pumpAndSettle();
      await tester.tap(recover);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Recover ledger'),
            )
            .onPressed,
        isNull,
      );
      final acknowledge = find.text(
        'I understand the backup will replace my active ledger.',
      );
      await tester.ensureVisible(acknowledge);
      await tester.pumpAndSettle();
      await tester.tap(acknowledge);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Recover ledger'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a failed or cancelled selection clears the old recovery preview',
    (tester) async {
      final files = _Files();
      final service = _FakeService();
      final container = await _openFailed(tester, files, service);
      await tester.runAsync(
        container.read(startupRecoveryProvider.notifier).chooseBackup,
      );
      await tester.pumpAndSettle();
      expect(find.text('Validated recovery backup'), findsOneWidget);
      files.bytes = Uint8List.fromList([255]);
      await tester.runAsync(
        container.read(startupRecoveryProvider.notifier).chooseBackup,
      );
      await tester.pumpAndSettle();
      expect(find.text('Recover using this backup'), findsNothing);
      files.bytes = null;
      await tester.runAsync(
        container.read(startupRecoveryProvider.notifier).chooseBackup,
      );
      await tester.pumpAndSettle();
      expect(find.text('File selection cancelled.'), findsOneWidget);
      expect(service.calls, 0);
    },
  );
  testWidgets(
    'recovery error hides filesystem details, retains preview and unlocks actions',
    (tester) async {
      final service = _FakeService()..fail = true;
      final container = await _openFailed(tester, _Files(), service);
      await tester.runAsync(
        container.read(startupRecoveryProvider.notifier).chooseBackup,
      );
      await tester.runAsync(
        container.read(startupRecoveryProvider.notifier).recover,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('/private/'), findsNothing);
      expect(find.textContaining('Recovery did not finish.'), findsOneWidget);
      expect(find.text('Validated recovery backup'), findsOneWidget);
      expect(container.read(ledgerTransferBusyProvider), isFalse);
      expect(container.read(ledgerResetSignalProvider), 0);
    },
  );
  test('a healthy ledger cannot invoke the startup recovery actions', () async {
    final files = _Files();
    final container = ProviderContainer(
      overrides: [
        databaseReadyProvider.overrideWith((ref) async {}),
        backupFilesProvider.overrideWithValue(files),
      ],
    );
    addTearDown(container.dispose);
    await container.read(databaseReadyProvider.future);
    await container.read(startupRecoveryProvider.notifier).chooseBackup();
    await container.read(startupRecoveryProvider.notifier).recover();
    expect(files.picks, 0);
    expect(container.read(ledgerTransferBusyProvider), isFalse);
    expect(
      container.read(startupRecoveryProvider).error,
      contains('only available'),
    );
  });
  testWidgets(
    'real failed database recovers, blocks Back while busy, reopens and applies the saved theme',
    (tester) async {
      late Directory root;
      late File old;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('startup-recovery-ui-');
        old = await File(
          p.join(root.path, ledgerFileName),
        ).writeAsString('unreadable ledger');
      });
      final store = LedgerStorage(root);
      final opened = <AppDatabase>[];
      final files = _Files();
      final closing = Completer<void>();
      final release = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = AppDatabase.withExecutor(
              LazyDatabase(
                () async =>
                    NativeDatabase(File(await store.activeDatabasePath())),
              ),
            );
            opened.add(db);
            return db;
          }),
          backupFilesProvider.overrideWithValue(files),
          startupRecoveryServiceProvider.overrideWith(
            (ref) => StartupRecoveryService(
              storage: () async => store,
              openCandidate: (file) =>
                  AppDatabase.withExecutor(NativeDatabase(file)),
              closeCurrentDatabase: () async {
                closing.complete();
                await release.future;
                await ref.read(databaseProvider).close();
              },
            ),
          ),
        ],
      );
      var disposed = false;
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        if (!disposed) container.dispose();
        for (final db in opened) {
          await db.close();
        }
        await root.delete(recursive: true);
      });
      await tester.runAsync(
        () => expectLater(
          container.read(databaseReadyProvider.future),
          throwsException,
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ExpenseTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to open your ledger'), findsOneWidget);
      await tester.tap(find.text('Recover from backup'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        container.read(startupRecoveryProvider.notifier).chooseBackup,
      );
      await tester.pumpAndSettle();
      container
          .read(historyFilterProvider.notifier)
          .set(
            TransactionFilter(query: 'old filter', categoryId: 'old-category'),
          );
      late Future<void> recovering;
      await tester.runAsync(() async {
        recovering = container.read(startupRecoveryProvider.notifier).recover();
        await _pumpUntil(tester, () => closing.isCompleted);
      });
      await tester.pump();
      expect(container.read(ledgerTransferBusyProvider), isTrue);
      await container
          .read(startupRecoveryProvider.notifier)
          .recover(); // Duplicate is ignored.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(StartupRecoveryScreen), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == 'Back',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(await tester.runAsync(old.readAsString), 'unreadable ledger');
      await tester.runAsync(() async {
        release.complete();
        await _pumpUntil(
          tester,
          () =>
              container.read(databaseReadyProvider).asData != null &&
              !container.read(ledgerTransferBusyProvider),
        );
        await recovering;
      });
      await tester.pumpAndSettle();
      expect(find.text('Your private ledger'), findsOneWidget);
      expect(
        container.read(historyFilterProvider),
        const TransactionFilter.empty(),
      );
      expect(find.byType(StartupRecoveryScreen), findsNothing);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      await tester.runAsync(() async {
        final active = File(await store.activeDatabasePath());
        expect(
          await File(
            p.join(active.parent.path, 'original', ledgerFileName),
          ).readAsString(),
          'unreadable ledger',
        );
        expect(await old.readAsString(), 'unreadable ledger');
        expect(
          (await container
                  .read(databaseProvider)
                  .customSelect('SELECT amount_myr_minor FROM transactions')
                  .getSingle())
              .read<int>('amount_myr_minor'),
          5625,
        );
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      disposed = true;
      await tester.pumpAndSettle();
    },
  );
}

Future<ProviderContainer> _openFailed(
  WidgetTester tester,
  _Files files,
  _FakeService service,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...emptyReportOverrides(),
        databaseReadyProvider.overrideWith(
          (ref) async => throw StateError('failed ledger'),
        ),
        backupFilesProvider.overrideWithValue(files),
        startupRecoveryServiceProvider.overrideWithValue(service),
      ],
      child: const ExpenseTrackerApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Recover from backup'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(StartupRecoveryScreen)),
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while (!done()) {
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException('Recovery did not finish');
    }
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _Files extends BackupFiles {
  Uint8List? bytes = BackupValidator.fromDocument(backupDocument()).encode();
  int picks = 0;
  @override
  Future<Uint8List?> pick() async {
    picks++;
    return bytes;
  }
}

class _FakeService extends StartupRecoveryService {
  _FakeService()
    : super(
        storage: () async => throw UnimplementedError(),
        closeCurrentDatabase: () async {},
      );
  int calls = 0;
  bool fail = false;
  @override
  Future<void> recover(
    ValidatedBackup backup, {
    void Function(RecoveryStage)? onStage,
  }) async {
    calls++;
    if (fail) throw const FileSystemException('/private/sensitive-ledger');
  }
}
