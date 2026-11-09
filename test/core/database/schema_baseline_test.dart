import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../generated_migrations/schema.dart';

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test(
    'v5 upgrade preserves the exact units of existing zero-decimal expenses',
    () async {
      final schema = await verifier.schemaAt(5);
      addTearDown(schema.rawDatabase.close);
      schema.rawDatabase.execute(
        "INSERT INTO currencies VALUES ('MYR','Ringgit','RM',2,'1',1,0,0), ('JPY','Yen','JPY',0,'0.03',1,0,0)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO categories VALUES ('food','Food','expense','restaurant','#123456',0,0)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO trips VALUES ('personal','Personal')",
      );
      schema.rawDatabase.execute(
        "INSERT INTO app_settings VALUES ('theme_mode','system')",
      );
      schema.rawDatabase.execute(
        "INSERT INTO transactions VALUES ('12345678-1234-4234-8234-123456789abc','food','expense',1000,'JPY','0.03',3000,'2026-11-09',NULL,0,0,'personal')",
      );
      final db = AppDatabase.forTesting(schema.newConnection());
      addTearDown(db.close);
      await db.initialize();
      await verifier.migrateAndValidate(db, 6);
      final row = await db
          .customSelect(
            'SELECT amount_minor, amount_decimal_places FROM transactions',
          )
          .getSingle();
      expect(row.read<int>('amount_minor'), 1000);
      expect(row.readNullable<int>('amount_decimal_places'), isNull);
    },
  );

  test(
    'fresh schema matches the exported v6 tables, indexes and triggers',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await verifier.migrateAndValidate(
        db,
        6,
        options: const ValidationOptions(validateDropped: true),
      );
      await db.initialize();
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test('migrating exported v1 preserves data and does not reseed defaults', () async {
    final schema = await verifier.schemaAt(1);
    addTearDown(schema.rawDatabase.close);
    schema.rawDatabase.execute(
      "INSERT INTO currencies VALUES ('MYR','Saved Ringgit','RM',2,'1',1,0,1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO categories VALUES ('saved','Saved category','expense','restaurant','#123456',0,1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO app_settings VALUES ('theme_mode','dark')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO transactions VALUES ('12345678-1234-4234-8234-123456789abc','saved','expense',1250,'MYR','1',1250,'2026-11-05','Historical',0,1)",
    );
    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await db.initialize();
    await verifier.migrateAndValidate(db, 6);
    expect(
      (await db
              .customSelect('SELECT count(*) AS n FROM categories')
              .getSingle())
          .read<int>('n'),
      1,
    );
    expect(
      (await db
              .customSelect("SELECT name FROM currencies WHERE code='MYR'")
              .getSingle())
          .read<String>('name'),
      'Saved Ringgit',
    );
    expect(
      (await db
              .customSelect(
                "SELECT amount_minor FROM transactions WHERE trip_id = 'personal'",
              )
              .getSingle())
          .read<int>('amount_minor'),
      1250,
    );
    expect(
      (await db.customSelect('SELECT value FROM app_settings').getSingle())
          .read<String>('value'),
      'dark',
    );
    await expectLater(
      db.customStatement("DELETE FROM currencies WHERE code='MYR'"),
      throwsException,
    );
  });

  test('migrating v2 preserves existing trip rates', () async {
    final schema = await verifier.schemaAt(2);
    addTearDown(schema.rawDatabase.close);
    schema.rawDatabase.execute(
      "INSERT INTO currencies VALUES ('MYR','Ringgit','RM',2,'1',1,0,0), ('THB','Baht','THB',2,'0.13',1,0,0)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO trips VALUES ('personal','Personal'), ('thailand','Thailand')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO trip_rates VALUES ('thailand','THB','0.12')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO app_settings VALUES ('theme_mode','system'), ('active_trip','thailand')",
    );
    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await db.initialize();
    await verifier.migrateAndValidate(db, 6);
    final row = await db
        .customSelect(
          "SELECT rate_to_myr, name FROM trip_rates WHERE trip_id = 'thailand'",
        )
        .getSingle();
    expect(row.read<String>('rate_to_myr'), '0.12');
    expect(row.readNullable<String>('name'), isNull);
  });

  test(
    'an unsupported future version fails without downgrading or resetting data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ledger-version-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/ledger.sqlite');
      final future = _FutureDatabase(NativeDatabase(file));
      try {
        await future.initialize();
        await future.customStatement(
          "UPDATE app_settings SET value = 'dark' WHERE key = 'theme_mode'",
        );
        await future.customStatement(
          'CREATE TABLE future_data (id INTEGER PRIMARY KEY)',
        );
        await future.customStatement('INSERT INTO future_data VALUES (42)');
      } finally {
        await future.close();
      }
      final current = AppDatabase.forTesting(NativeDatabase(file));
      try {
        await expectLater(current.initialize(), throwsUnsupportedError);
      } finally {
        await current.close();
      }
      final reopened = _FutureDatabase(NativeDatabase(file));
      try {
        await reopened.initialize();
        expect(
          (await reopened.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          7,
        );
        expect(
          (await reopened
                  .customSelect('SELECT id FROM future_data')
                  .getSingle())
              .read<int>('id'),
          42,
        );
        expect(
          (await reopened
                  .customSelect('SELECT value FROM app_settings')
                  .getSingle())
              .read<String>('value'),
          'dark',
        );
      } finally {
        await reopened.close();
      }
    },
  );
}

// Synthetic future file only. This does not introduce a production v7 migration.
class _FutureDatabase extends AppDatabase {
  _FutureDatabase(super.executor) : super.forTesting();
  @override
  int get schemaVersion => 7;
}
