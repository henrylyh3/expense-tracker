import 'dart:io';

import 'package:drift/native.dart';
import 'package:expense_tracker/core/backup/backup_service.dart';
import 'package:expense_tracker/core/backup/backup_validator.dart';
import 'package:expense_tracker/core/backup/startup_recovery_service.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/database/ledger_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../test/support/backup_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'default background recovery preserves an unreadable ledger and activates a valid file',
    (tester) async {
      // Isolated synthetic cache storage, never the application's normal ledger.
      final root = await Directory(
        (await getTemporaryDirectory()).path,
      ).createTemp('recovery-integration-');
      final store = LedgerStorage(root);
      final source = await File(
        p.join(root.path, ledgerFileName),
      ).writeAsString('unreadable original', flush: true);
      final failed = AppDatabase.withExecutor(NativeDatabase(source));
      AppDatabase? reopened;
      try {
        await expectLater(failed.initialize(), throwsException);
        final backup = BackupValidator.fromDocument(backupDocument());
        await StartupRecoveryService(
          storage: () async => store,
          closeCurrentDatabase: failed.close,
        ).recover(backup);
        final active = File(await LedgerStorage(root).activeDatabasePath());
        expect(await source.readAsString(), 'unreadable original');
        expect(
          await File(
            p.join(active.parent.path, 'original', ledgerFileName),
          ).readAsString(),
          'unreadable original',
        );
        reopened = AppDatabase.withExecutor(
          NativeDatabase.createInBackground(active),
        );
        await reopened.initialize();
        expect(
          BackupValidator.decode(
            await BackupService(reopened).exportBytes(),
          ).tables,
          backup.tables,
        );
      } finally {
        await failed.close();
        await reopened?.close();
        await root.delete(recursive: true);
      }
    },
  );
}
