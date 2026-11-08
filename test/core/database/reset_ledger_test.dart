import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.initialize();
    await db.customStatement("INSERT INTO trips VALUES ('holiday','Holiday')");
    await db.customStatement(
      "INSERT INTO currencies VALUES ('THB','Baht','THB',2,'0.13',1,0,0)",
    );
    await db.customStatement(
      "INSERT INTO currency_rates VALUES ('thb25','THB','THB 2025','0.12',1)",
    );
    await db.customStatement(
      "INSERT INTO trip_rates VALUES ('holiday','THB','0.12','THB 2025','thb25')",
    );
    await db.customStatement(
      "INSERT INTO transactions VALUES ('12345678-1234-4234-8234-123456789abc','seed-food','expense',10000,'THB','0.12',1200,'2026-11-08',NULL,0,0,'holiday')",
    );
    await db.customStatement(
      "INSERT INTO app_settings VALUES ('active_trip','holiday'),('default_currency','THB'),('default_rate','thb25')",
    );
  });
  tearDown(() => db.close());

  test(
    'reset removes all user data and restores usable initial defaults',
    () async {
      await db.resetLedger();
      for (final table in ['transactions', 'trip_rates', 'currency_rates']) {
        expect(await db.customSelect('SELECT * FROM $table').get(), isEmpty);
      }
      expect(
        (await db.customSelect('SELECT code FROM currencies').getSingle())
            .read<String>('code'),
        'MYR',
      );
      expect(
        (await db.customSelect('SELECT id FROM trips').getSingle())
            .read<String>('id'),
        'personal',
      );
      expect(
        (await db.customSelect('SELECT key FROM app_settings').getSingle())
            .read<String>('key'),
        'theme_mode',
      );
      expect(
        (await db
                .customSelect(
                  "SELECT name FROM categories WHERE id = 'seed-food'",
                )
                .getSingle())
            .read<String>('name'),
        'Food',
      );
      await db.initialize();
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test('failed reset rolls back removed records and preferences', () async {
    await db.customStatement(
      "CREATE TRIGGER reject_reset BEFORE INSERT ON categories BEGIN SELECT RAISE(ABORT,'injected reset failure'); END",
    );
    await expectLater(db.resetLedger(), throwsException);
    expect(
      (await db.customSelect('SELECT trip_id FROM transactions').getSingle())
          .read<String>('trip_id'),
      'holiday',
    );
    expect(
      (await db
              .customSelect(
                "SELECT value FROM app_settings WHERE key = 'active_trip'",
              )
              .getSingle())
          .read<String>('value'),
      'holiday',
    );
    expect(
      (await db.customSelect('SELECT name FROM currency_rates').getSingle())
          .read<String>('name'),
      'THB 2025',
    );
    await db.initialize();
  });
}
