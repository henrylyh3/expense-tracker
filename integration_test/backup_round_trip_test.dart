import 'dart:io';

import 'package:drift/native.dart';
import 'package:expense_tracker/core/backup/backup_reader.dart';
import 'package:expense_tracker/core/backup/backup_service.dart';
import 'package:expense_tracker/core/backup/backup_validator.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/features/reports/data/report_repository.dart';
import 'package:expense_tracker/features/reports/domain/report_period.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../test/support/backup_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native backup file and restored ledger survive database reopen',
    (tester) async {
      // Isolated synthetic ledger in OS cache; never touches the user's ledger.
      final directory = await Directory(
        (await getTemporaryDirectory()).path,
      ).createTemp('ledger-round-trip-');
      AppDatabase? db;
      try {
        final ledgerFile = File(p.join(directory.path, 'test-ledger.sqlite'));
        final backupFile = File(p.join(directory.path, 'backup.json'));
        final safetyFile = File(p.join(directory.path, 'safety.json'));
        db = AppDatabase.forTesting(NativeDatabase(ledgerFile));
        await db.initialize();
        await BackupService(
          db,
        ).restore(BackupValidator.fromDocument(backupDocument()));
        await backupFile.writeAsBytes(
          await BackupService(db).exportBytes(),
          flush: true,
        );
        await db.writeTransaction(
          () => db!.customStatement(
            "UPDATE currencies SET rate_to_myr = '4.9' WHERE code = 'USD'",
          ),
        );
        final imported = BackupValidator.decode(
          await readBackupStream(
            backupFile.openRead(),
            reportedLength: await backupFile.length(),
          ),
        );
        expect(imported.count('transactions'), 1);
        expect(
          await BackupService(db).restore(
            imported,
            saveSafetyBackup: (bytes) async {
              await safetyFile.writeAsBytes(bytes, flush: true);
              return true;
            },
          ),
          RestoreOutcome.restored,
        );
        expect(
          BackupValidator.decode(
            await safetyFile.readAsBytes(),
          ).tables['currencies']!.last['rate_to_myr'],
          '4.9',
        );
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(ledgerFile));
        await db.initialize();
        final saved = BackupValidator.decode(
          await BackupService(db).exportBytes(),
        );
        expect(saved.tables, imported.tables);
        final report = await ReportRepository(
          db,
        ).watchPeriod(ReportPeriod.month(2026, 11)).first;
        expect(report.expenseMinor, 5625);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
