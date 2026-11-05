import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:expense_tracker/core/backup/backup_service.dart';
import 'package:expense_tracker/core/backup/backup_validator.dart';
import 'package:expense_tracker/core/backup/startup_recovery_service.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/database/ledger_storage.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_fixture.dart';

void main() {
  late Directory root;
  late LedgerStorage store;
  var closed = false;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('ledger-recovery-');
    store = LedgerStorage(root);
    closed = false;
    await File(
      p.join(root.path, ledgerFileName),
    ).writeAsString('unreadable original');
  });
  tearDown(() => root.delete(recursive: true));
  StartupRecoveryService service({
    LedgerStorage? storage,
    Future<void> Function()? close,
    AppDatabase Function(File)? open,
  }) => StartupRecoveryService(
    storage: () async => storage ?? store,
    closeCurrentDatabase:
        close ??
        () async {
          closed = true;
        },
    openCandidate:
        open ?? (file) => AppDatabase.withExecutor(NativeDatabase(file)),
  );
  Future<void> unchanged() async {
    expect(await store.activeDatabasePath(), p.join(root.path, ledgerFileName));
    expect(
      await File(p.join(root.path, ledgerFileName)).readAsString(),
      'unreadable original',
    );
  }

  test('recovers exact data and preserves pre-close SQLite sidecars', () async {
    final wal = File(p.join(root.path, '$ledgerFileName-wal'));
    await wal.writeAsString('original WAL');
    await service(
      close: () async {
        closed = true;
        await wal.delete();
      },
    ).recover(BackupValidator.fromDocument(backupDocument()));
    expect(closed, isTrue);
    final active = File(await LedgerStorage(root).activeDatabasePath());
    expect(active.path, isNot(p.join(root.path, ledgerFileName)));
    final original = Directory(p.join(active.parent.path, 'original'));
    expect(
      await File(p.join(original.path, ledgerFileName)).readAsString(),
      'unreadable original',
    );
    expect(
      await File(p.join(original.path, '$ledgerFileName-wal')).readAsString(),
      'original WAL',
    );
    final reopened = AppDatabase.withExecutor(NativeDatabase(active));
    try {
      await reopened.initialize();
      expect(
        BackupValidator.decode(
          await BackupService(reopened).exportBytes(),
        ).tables,
        BackupValidator.fromDocument(backupDocument()).tables,
      );
    } finally {
      await reopened.close();
    }
  });
  test('empty restored categories remain empty on reopen', () async {
    final document = backupDocument();
    for (final table in ['categories', 'transactions']) {
      document['data'][table].clear();
      document['counts'][table] = 0;
    }
    await service().recover(BackupValidator.fromDocument(document));
    final db = AppDatabase.withExecutor(
      NativeDatabase(File(await store.activeDatabasePath())),
    );
    try {
      await db.initialize();
      expect(await db.customSelect('SELECT * FROM categories').get(), isEmpty);
    } finally {
      await db.close();
    }
  });
  for (final stage in RecoveryStage.values) {
    test(
      'injected failure at ${stage.name} never activates partial data',
      () async {
        await expectLater(
          service().recover(
            BackupValidator.fromDocument(backupDocument()),
            onStage: (value) {
              if (value == stage) throw StateError('simulated interruption');
            },
          ),
          throwsStateError,
        );
        await unchanged();
      },
    );
  }
  test(
    'preservation failure aborts before closing the original database',
    () async {
      await expectLater(
        service(
          storage: _CannotPreserve(root),
        ).recover(BackupValidator.fromDocument(backupDocument())),
        throwsA(isA<FileSystemException>()),
      );
      expect(closed, isFalse);
      await unchanged();
    },
  );
  test('failed original close aborts before creating a new ledger', () async {
    await expectLater(
      service(
        close: () async => throw StateError('close failed'),
      ).recover(BackupValidator.fromDocument(backupDocument())),
      throwsStateError,
    );
    await unchanged();
    final files = await root.list(recursive: true).toList();
    expect(
      files
          .whereType<File>()
          .where((f) => p.basename(f.path) == ledgerFileName)
          .length,
      2,
    ); // Original + archive only.
  });
  test(
    'failed candidate transaction leaves the old selection active',
    () async {
      await expectLater(
        service(
          open: _RejectRestore.new,
        ).recover(BackupValidator.fromDocument(backupDocument())),
        throwsException,
      );
      await unchanged();
    },
  );
  test('health-valid but altered round-trip data cannot activate', () async {
    await expectLater(
      service(
        open: _AlterVerifiedData.new,
      ).recover(BackupValidator.fromDocument(backupDocument())),
      throwsA(isA<LedgerException>()),
    );
    await unchanged();
  });
  test('failed candidate close cannot activate', () async {
    await expectLater(
      service(
        open: _CannotClose.new,
      ).recover(BackupValidator.fromDocument(backupDocument())),
      throwsStateError,
    );
    await unchanged();
  });
  test(
    'failed selector commit keeps the closed validated candidate inactive',
    () async {
      await expectLater(
        service(
          storage: _CannotActivate(root),
        ).recover(BackupValidator.fromDocument(backupDocument())),
        throwsA(isA<FileSystemException>()),
      );
      await unchanged();
    },
  );
  test(
    'duplicate recovery is rejected while preserving a single operation',
    () async {
      final waiting = Completer<void>();
      final release = Completer<void>();
      final runner = service(
        close: () async {
          waiting.complete();
          await release.future;
        },
      );
      final first = runner.recover(
        BackupValidator.fromDocument(backupDocument()),
      );
      await waiting.future;
      await expectLater(
        runner.recover(BackupValidator.fromDocument(backupDocument())),
        throwsA(isA<LedgerException>()),
      );
      release.complete();
      await first;
      expect(await File(await store.activeDatabasePath()).exists(), isTrue);
    },
  );
}

class _CannotPreserve extends LedgerStorage {
  _CannotPreserve(super.directory);
  @override
  Future<RecoveryWorkspace> preserveOriginals() async =>
      throw const FileSystemException('preservation failed');
}

class _CannotActivate extends LedgerStorage {
  _CannotActivate(super.directory);
  @override
  Future<void> activate(RecoveryWorkspace workspace) async =>
      throw const FileSystemException('activation failed');
}

class _RejectRestore extends AppDatabase {
  _RejectRestore(File file) : super.withExecutor(NativeDatabase(file));
  @override
  Future<void> initialize() async {
    await super.initialize();
    await customStatement(
      "CREATE TRIGGER IF NOT EXISTS reject_restore BEFORE INSERT ON transactions BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
    );
  }
}

class _AlterVerifiedData extends AppDatabase {
  _AlterVerifiedData(File file) : super.withExecutor(NativeDatabase(file));
  int calls = 0;
  @override
  Future<void> initialize() async {
    await super.initialize();
    if (++calls == 2) {
      await customStatement("UPDATE transactions SET note = 'altered'");
    }
  }
}

class _CannotClose extends AppDatabase {
  _CannotClose(File file) : super.withExecutor(NativeDatabase(file));
  @override
  Future<void> close() async {
    await super.close();
    throw StateError('close failed');
  }
}
