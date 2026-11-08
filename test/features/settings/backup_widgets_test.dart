import 'dart:typed_data';

import 'package:expense_tracker/core/backup/backup_files.dart';
import 'package:expense_tracker/core/backup/backup_service.dart';
import 'package:expense_tracker/core/backup/backup_validator.dart';
import 'package:expense_tracker/core/providers/ledger_operation_providers.dart';
import 'package:expense_tracker/features/settings/presentation/backup_screen.dart';
import 'package:expense_tracker/features/settings/presentation/backup_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/backup_fixture.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    BackupFiles files,
    BackupService service,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupFilesProvider.overrideWithValue(files),
          backupServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: Scaffold(body: BackupScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Export JSON opens the save flow with a valid backup', (
    tester,
  ) async {
    final files = _Files();
    await open(tester, files, _Service());
    await tester.tap(find.text('Export JSON'));
    await tester.pumpAndSettle();
    expect(files.exportedBytes, isNotNull);
    expect(
      BackupValidator.decode(files.exportedBytes!).count('transactions'),
      1,
    );
    expect(find.text('Save cancelled.'), findsOneWidget);
  });

  testWidgets('preview is read-only and replacement requires acknowledgment', (
    tester,
  ) async {
    final files = _Files();
    final service = _Service();
    await open(tester, files, service);
    await tester.runAsync(
      ProviderScope.containerOf(
        tester.element(find.byType(BackupScreen)),
      ).read(backupActionsProvider.notifier).chooseBackup,
    );
    await tester.pumpAndSettle();
    expect(find.text('Validated backup'), findsOneWidget);
    expect(service.restores, 0);
    await tester.ensureVisible(find.text('Import this backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import this backup'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Replace all'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Save a safety backup first'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.restores, 0);
  });
  testWidgets('failed selection clears the previous preview', (tester) async {
    final files = _Files();
    await open(tester, files, _Service());
    await tester.runAsync(
      ProviderScope.containerOf(
        tester.element(find.byType(BackupScreen)),
      ).read(backupActionsProvider.notifier).chooseBackup,
    );
    await tester.pumpAndSettle();
    expect(find.text('Validated backup'), findsOneWidget);
    files.fail = true;
    await tester.tap(find.text('Choose JSON file'));
    await tester.pumpAndSettle();
    expect(find.text('Validated backup'), findsNothing);
    expect(find.text('Import this backup'), findsNothing);
  });
  testWidgets('cancelled safety save does not reset navigation', (
    tester,
  ) async {
    final files = _Files();
    final service = _Service();
    await open(tester, files, service);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BackupScreen)),
    );
    await tester.runAsync(
      container.read(backupActionsProvider.notifier).chooseBackup,
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => container
          .read(backupActionsProvider.notifier)
          .restore(safetyBackup: true),
    );
    await tester.pumpAndSettle();
    expect(files.safetySaves, 1);
    expect(container.read(ledgerResetSignalProvider), 0);
    expect(container.read(ledgerTransferBusyProvider), isFalse);
    expect(
      find.text('Safety backup cancelled. Your ledger has not been replaced.'),
      findsOneWidget,
    );
  });
}

class _Files extends BackupFiles {
  Uint8List? exportedBytes;
  bool fail = false;
  int safetySaves = 0;
  @override
  Future<Uint8List?> pick() async {
    if (fail) throw StateError('provider failure');
    return BackupValidator.fromDocument(backupDocument()).encode();
  }

  @override
  Future<bool> save(Uint8List bytes, {bool safety = false}) async {
    if (!safety) exportedBytes = bytes;
    if (safety) safetySaves++;
    return false;
  }
}

class _Service implements BackupService {
  int restores = 0;
  @override
  Future<Uint8List> exportBytes() async =>
      BackupValidator.fromDocument(backupDocument()).encode();
  @override
  Future<RestoreOutcome> restore(
    ValidatedBackup backup, {
    Future<bool> Function(Uint8List)? saveSafetyBackup,
  }) async {
    restores++;
    if (saveSafetyBackup != null &&
        !await saveSafetyBackup(await exportBytes())) {
      return RestoreOutcome.cancelled;
    }
    return RestoreOutcome.restored;
  }
}
