import 'dart:convert';
import 'dart:io';

import 'package:expense_tracker/core/database/ledger_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late LedgerStorage store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('ledger-selection-');
    store = LedgerStorage(root);
  });
  tearDown(() => root.delete(recursive: true));
  File file(String name) => File(p.join(root.path, name));

  test('legacy selection creates no files', () async {
    expect(await store.activeDatabasePath(), file(ledgerFileName).path);
    expect(await root.list().toList(), isEmpty);
  });
  test('preserves main and every SQLite sidecar before switching', () async {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      await file('$ledgerFileName$suffix').writeAsString('original$suffix');
    }
    final work = await store.preserveOriginals();
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      expect(
        await File(
          p.join(work.originals.path, '$ledgerFileName$suffix'),
        ).readAsString(),
        'original$suffix',
      );
      expect(
        await file('$ledgerFileName$suffix').readAsString(),
        'original$suffix',
      );
    }
    await work.databaseFile.writeAsString('candidate', flush: true);
    await store.activate(work);
    expect(
      await LedgerStorage(root).activeDatabasePath(),
      work.databaseFile.path,
    );
    expect(await file(ledgerFileName).readAsString(), 'original');
  });
  test(
    'an uncommitted candidate and temporary pointer are ignored on restart',
    () async {
      await file(ledgerFileName).writeAsString('old');
      final work = await store.preserveOriginals();
      await work.databaseFile.writeAsString('partial');
      await file('.active-${work.id}.tmp').writeAsString('{"partial":');
      expect(
        await LedgerStorage(root).activeDatabasePath(),
        file(ledgerFileName).path,
      );
      expect(await file(ledgerFileName).readAsString(), 'old');
    },
  );
  test(
    'a second recovery preserves the previous selector and selected generation',
    () async {
      await file(ledgerFileName).writeAsString('legacy');
      final first = await store.preserveOriginals();
      await first.databaseFile.writeAsString('first');
      await store.activate(first);
      final pointer = await file('active-ledger.json').readAsBytes();
      await File('${first.databaseFile.path}-wal').writeAsString('first WAL');
      final second = await store.preserveOriginals();
      expect(
        await File(
          p.join(second.originals.path, ledgerFileName),
        ).readAsString(),
        'first',
      );
      expect(
        await File(
          p.join(second.originals.path, '$ledgerFileName-wal'),
        ).readAsString(),
        'first WAL',
      );
      expect(
        await File(
          p.join(second.originals.path, 'active-ledger.json'),
        ).readAsBytes(),
        pointer,
      );
      await second.databaseFile.writeAsString('second');
      await store.activate(second);
      expect(await first.databaseFile.readAsString(), 'first');
      expect(await file(ledgerFileName).readAsString(), 'legacy');
      expect(await store.activeDatabasePath(), second.databaseFile.path);
    },
  );
  test(
    'refuses activation if selection changed while the candidate was built',
    () async {
      final a = await store.preserveOriginals();
      final b = await store.preserveOriginals();
      await a.databaseFile.writeAsString('a');
      await b.databaseFile.writeAsString('b');
      await store.activate(b);
      await expectLater(store.activate(a), throwsStateError);
      expect(await store.activeDatabasePath(), b.databaseFile.path);
    },
  );
  test(
    'pointer write failure leaves the previous selection untouched',
    () async {
      final work = await store.preserveOriginals();
      await work.databaseFile.writeAsString('candidate');
      await Directory(file('.active-${work.id}.tmp').path).create();
      await expectLater(
        store.activate(work),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file('active-ledger.json').exists(), isFalse);
      expect(await store.activeDatabasePath(), file(ledgerFileName).path);
    },
  );
  for (final source in [
    '{',
    '{}',
    '{"format_version":2,"id":"generation-a"}',
    '{"format_version":1,"id":"../../outside"}',
    '{"format_version":1,"id":"/outside"}',
    '{"format_version":1,"id":"generation-a","id":"generation-b"}',
    '{"id":"generation-a","format_version":1}',
    ' ' * 4097,
  ]) {
    test(
      'invalid selector fails closed (${source.length}, ${source.hashCode})',
      () async {
        await file('active-ledger.json').writeAsString(source);
        await expectLater(store.activeDatabasePath(), throwsStateError);
        expect(await file(ledgerFileName).exists(), isFalse);
      },
    );
  }
  test(
    'malformed small selector is archived and can be replaced explicitly',
    () async {
      await file('active-ledger.json').writeAsString('invalid');
      await file(ledgerFileName).writeAsString('legacy bytes');
      final work = await store.preserveOriginals();
      expect(
        await File(
          p.join(work.originals.path, 'active-ledger.json'),
        ).readAsString(),
        'invalid',
      );
      await work.databaseFile.writeAsString('new');
      await store.activate(work);
      expect(await store.activeDatabasePath(), work.databaseFile.path);
    },
  );
  test(
    'missing selected ledger fails without seeding or reverting to legacy',
    () async {
      final work = await store.preserveOriginals();
      await work.databaseFile.writeAsString('candidate');
      await store.activate(work);
      await work.databaseFile.delete();
      await expectLater(
        LedgerStorage(root).activeDatabasePath(),
        throwsStateError,
      );
      expect(await file(ledgerFileName).exists(), isFalse);
    },
  );
  test(
    'does not follow symbolic links for recovery storage or the active file',
    () async {
      final external = await Directory.systemTemp.createTemp(
        'external-ledger-',
      );
      try {
        await Link(p.join(root.path, 'recovery')).create(external.path);
        await expectLater(store.preserveOriginals(), throwsStateError);
        expect(await external.list().toList(), isEmpty);
        await Link(p.join(root.path, 'recovery')).delete();
        final work = await store.preserveOriginals();
        final externalFile = await File(
          p.join(external.path, 'data'),
        ).writeAsString('outside');
        await Link(file(ledgerFileName).path).create(externalFile.path);
        await expectLater(store.activeDatabasePath(), throwsStateError);
        await Link(file(ledgerFileName).path).delete();
        await Link(work.databaseFile.path).create(externalFile.path);
        await expectLater(store.activate(work), throwsStateError);
        expect(await externalFile.readAsString(), 'outside');
      } finally {
        await external.delete(recursive: true);
      }
    },
  );
  test('preservation metadata records actual archived byte lengths', () async {
    await file(ledgerFileName).writeAsBytes([0, 1, 255]);
    final work = await store.preserveOriginals();
    final metadata =
        jsonDecode(
              await File(
                p.join(work.directory.path, 'preservation.json'),
              ).readAsString(),
            )
            as Map<String, dynamic>;
    expect(metadata['files'], [
      {'name': ledgerFileName, 'bytes': 3},
    ]);
  });
}
