import 'dart:async';

import 'package:drift/native.dart';
import 'package:expense_tracker/core/backup/backup_service.dart';
import 'package:expense_tracker/core/backup/backup_validator.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/backup_fixture.dart';

void main() {
  late AppDatabase db;
  late BackupService service;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.initialize();
    service = BackupService(db);
  });
  tearDown(() => db.close());
  Future<List<Map<String, Object?>>> rows(String table) async =>
      (await db.customSelect('SELECT * FROM $table').get())
          .map((row) => row.data)
          .toList();
  test('exports every table from a consistent, valid snapshot', () async {
    final backup = BackupValidator.decode(await service.exportBytes());
    expect(backup.count('categories'), 10);
    expect(backup.count('currencies'), 1);
    expect(backup.count('transactions'), 0);
    expect(backup.count('settings'), 1);
  });
  test(
    'replace all preserves archived references, rates, settings and MYR metadata',
    () async {
      final document = backupDocument();
      document['data']['currencies'][0]['name'] = 'Ringgit restored';
      expect(
        await service.restore(BackupValidator.fromDocument(document)),
        RestoreOutcome.restored,
      );
      final exported = BackupValidator.decode(await service.exportBytes());
      expect(exported.tables, BackupValidator.fromDocument(document).tables);
      expect((await rows('categories')).single['is_archived'], 1);
      expect(
        (await rows(
          'currencies',
        )).firstWhere((r) => r['code'] == 'MYR')['name'],
        'Ringgit restored',
      );
      expect(
        (await rows('transactions')).single['exchange_rate_snapshot'],
        '4.5000',
      );
      expect((await rows('app_settings')).single['value'], 'dark');
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
  test(
    'safety cancellation and failure leave the existing ledger unchanged',
    () async {
      final before = await rows('categories');
      final backup = BackupValidator.fromDocument(backupDocument());
      expect(
        await service.restore(
          backup,
          saveSafetyBackup: (bytes) async {
            expect(BackupValidator.decode(bytes).count('categories'), 10);
            return false;
          },
        ),
        RestoreOutcome.cancelled,
      );
      expect(await rows('categories'), before);
      await expectLater(
        service.restore(
          backup,
          saveSafetyBackup: (_) async => throw StateError('save failed'),
        ),
        throwsStateError,
      );
      expect(await rows('categories'), before);
      expect(await rows('transactions'), isEmpty);
    },
  );
  test(
    'a late SQL failure rolls back deletes, MYR update, parents and settings',
    () async {
      final before = BackupValidator.decode(await service.exportBytes()).tables;
      await db.customStatement(
        "CREATE TRIGGER reject_restore BEFORE INSERT ON transactions BEGIN SELECT RAISE(ABORT, 'test rollback'); END",
      );
      await expectLater(
        service.restore(BackupValidator.fromDocument(backupDocument())),
        throwsA(anything),
      );
      expect(
        BackupValidator.decode(await service.exportBytes()).tables,
        before,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
  test('queued edits cannot write into the replacement ledger', () async {
    final saving = Completer<void>();
    final release = Completer<void>();
    final restore = service.restore(
      BackupValidator.fromDocument(backupDocument()),
      saveSafetyBackup: (_) async {
        saving.complete();
        await release.future;
        return true;
      },
    );
    await saving.future;
    final stale = expectLater(
      db.writeTransaction(
        () => db.customStatement("UPDATE app_settings SET value = 'light'"),
      ),
      throwsA(isA<LedgerException>()),
    );
    release.complete();
    await restore;
    await stale;
    expect((await rows('app_settings')).single['value'], 'dark');
  });
  test(
    'streams publish committed replacement and empty backups do not reseed',
    () async {
      final events = <int>[];
      final repository = CategoryRepository(db);
      final initial = Completer<void>();
      final replaced = Completer<void>();
      final subscription = repository.watchAll().listen((rows) {
        events.add(rows.length);
        if (!initial.isCompleted) initial.complete();
        if (rows.length == 1 && !replaced.isCompleted) replaced.complete();
      });
      addTearDown(subscription.cancel);
      await initial.future;
      await service.restore(BackupValidator.fromDocument(backupDocument()));
      await replaced.future.timeout(const Duration(seconds: 5));
      expect(
        events,
        everyElement(anyOf(10, 1)),
      ); // Never an intermediate empty table.
      final empty = backupDocument();
      for (final table in ['categories', 'transactions']) {
        empty['data'][table].clear();
        empty['counts'][table] = 0;
      }
      await service.restore(BackupValidator.fromDocument(empty));
      expect(await rows('categories'), isEmpty);
      expect(await rows('transactions'), isEmpty);
    },
  );
}
