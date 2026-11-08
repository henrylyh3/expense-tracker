import 'dart:io';

import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.initialize();
  });
  tearDown(() => db.close());

  test(
    'initialization is read-only and preserves an intentionally empty ledger',
    () async {
      await db.customStatement('DELETE FROM categories');
      await db.customStatement(
        "UPDATE app_settings SET value = 'dark' WHERE key = 'theme_mode'",
      );
      await db.initialize();
      await db.initialize();
      expect(await db.customSelect('SELECT * FROM categories').get(), isEmpty);
      expect(
        (await db.customSelect('SELECT value FROM app_settings').getSingle())
            .read<String>('value'),
        'dark',
      );
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        5,
      );
    },
  );
  for (final (kind, sql) in [
    ('table', 'DROP TABLE transactions'),
    ('index', 'DROP INDEX transactions_date_idx'),
    ('trigger', 'DROP TRIGGER protect_myr_delete'),
  ]) {
    test('refuses a missing $kind without recreating schema objects', () async {
      await db.customStatement(sql);
      final before =
          (await db
                  .customSelect(
                    'SELECT name, type, sql FROM sqlite_schema ORDER BY name',
                  )
                  .get())
              .map((r) => r.data)
              .toList();
      await expectLater(db.initialize(), throwsStateError);
      final after =
          (await db
                  .customSelect(
                    'SELECT name, type, sql FROM sqlite_schema ORDER BY name',
                  )
                  .get())
              .map((r) => r.data)
              .toList();
      expect(after, before);
    });
  }
  test('refuses renamed columns without rewriting settings', () async {
    await db.customStatement(
      'ALTER TABLE app_settings RENAME COLUMN value TO unexpected_value',
    );
    await expectLater(db.initialize(), throwsStateError);
    expect(
      (await db
              .customSelect('SELECT unexpected_value FROM app_settings')
              .getSingle())
          .read<String>('unexpected_value'),
      'system',
    );
  });
  test(
    'refuses existing CHECK violations and preserves offending data',
    () async {
      await db.customStatement('PRAGMA ignore_check_constraints = ON');
      await db.customStatement(
        '''INSERT INTO transactions VALUES
      ('12345678-1234-4234-8234-123456789abc','seed-food','expense',0,'MYR','1',0,'2026-11-05',NULL,0,0, 'personal')''',
      );
      await db.customStatement('PRAGMA ignore_check_constraints = OFF');
      await expectLater(db.initialize(), throwsStateError);
      expect(
        (await db
                .customSelect('SELECT amount_minor FROM transactions')
                .getSingle())
            .read<int>('amount_minor'),
        0,
      );
    },
  );
  test(
    'refuses dangling currency references even when quick_check is ok',
    () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.customStatement(
        '''INSERT INTO transactions VALUES
      ('12345678-1234-4234-8234-123456789abc','seed-food','expense',100,'ZZZ','1',100,'2026-11-05',NULL,0,0, 'personal')''',
      );
      await db.customStatement('PRAGMA foreign_keys = ON');
      expect(
        (await db.customSelect('PRAGMA quick_check(1)').getSingle())
            .data
            .values
            .single,
        'ok',
      );
      await expectLater(db.initialize(), throwsStateError);
      expect(
        (await db
                .customSelect('SELECT currency_code FROM transactions')
                .getSingle())
            .read<String>('currency_code'),
        'ZZZ',
      );
    },
  );
  test('refuses a disabled foreign-key connection', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await expectLater(db.initialize(), throwsStateError);
  });
  test(
    'refuses a schema-valid ledger missing MYR without reseeding it',
    () async {
      await db.customStatement('DROP TRIGGER protect_myr_delete');
      await db.customStatement("DELETE FROM currencies WHERE code = 'MYR'");
      // Restore the original guard so absence of MYR is the sole health failure.
      final guard = db.allSchemaEntities
          .where((e) => e.entityName == 'protect_myr_delete')
          .single;
      await db.createMigrator().create(guard);
      await expectLater(db.initialize(), throwsStateError);
      expect(await db.customSelect('SELECT * FROM currencies').get(), isEmpty);
    },
  );
  for (final value in [null, 'unsupported']) {
    test(
      'refuses ${value == null ? 'missing' : 'invalid'} theme settings without defaulting',
      () async {
        if (value == null) {
          await db.customStatement(
            "DELETE FROM app_settings WHERE key = 'theme_mode'",
          );
        } else {
          await db.customStatement('UPDATE app_settings SET value = ?', [
            value,
          ]);
        }
        await expectLater(db.initialize(), throwsStateError);
        final rows = await db
            .customSelect('SELECT value FROM app_settings')
            .get();
        expect(
          rows.map((r) => r.read<String>('value')),
          value == null ? isEmpty : [value],
        );
      },
    );
  }
  test('an unreadable SQLite file is never truncated or replaced', () async {
    await db.close();
    final directory = await Directory.systemTemp.createTemp('ledger-invalid-');
    final file = File('${directory.path}/ledger.sqlite');
    const original = [
      110,
      111,
      116,
      32,
      97,
      32,
      100,
      97,
      116,
      97,
      98,
      97,
      115,
      101,
    ];
    await file.writeAsBytes(original, flush: true);
    final broken = AppDatabase.forTesting(NativeDatabase(file));
    try {
      await expectLater(broken.initialize(), throwsException);
    } finally {
      await broken.close();
    }
    try {
      expect(await file.readAsBytes(), original);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
