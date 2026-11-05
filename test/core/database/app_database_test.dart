import 'dart:io';

import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.initialize();
  });
  tearDown(() => database.close());

  test('creates defaults and enables foreign keys', () async {
    final myr = await database
        .customSelect("SELECT * FROM currencies WHERE code = 'MYR'")
        .getSingle();
    expect(myr.read<String>('rate_to_myr'), '1');
    expect(myr.read<int>('decimal_places'), 2);
    final count = await database
        .customSelect('SELECT count(*) AS n FROM categories')
        .getSingle();
    expect(count.read<int>('n'), 10);
    expect(
      await database.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
  });

  test('MYR cannot be deleted, renamed, archived or repriced', () async {
    for (final statement in [
      "DELETE FROM currencies WHERE code = 'MYR'",
      "UPDATE currencies SET code = 'XXX' WHERE code = 'MYR'",
      "UPDATE currencies SET is_active = 0 WHERE code = 'MYR'",
      "UPDATE currencies SET decimal_places = 0 WHERE code = 'MYR'",
      "UPDATE currencies SET rate_to_myr = '2' WHERE code = 'MYR'",
    ]) {
      await expectLater(database.customStatement(statement), throwsException);
    }
  });

  test('rejects missing currency and category/type mismatch', () async {
    await expectLater(_insert(database, currency: 'USD'), throwsException);
    await expectLater(_insert(database, type: 'income'), throwsException);
  });

  test('rejects non-money values and invalid calendar dates', () async {
    for (final amount in [0, -1]) {
      await expectLater(_insert(database, amount: amount), throwsException);
    }
    for (final date in ['2026-02-29', '2026-04-31', '2026-13-01']) {
      await expectLater(_insert(database, date: date), throwsException);
    }
    await _insert(database, date: '2024-02-29');
  });

  test('changing default FX does not alter historical values', () async {
    await _addUsd(database);
    await _insert(database, currency: 'USD', rate: '4.5', myr: 5625);
    await database.customStatement(
      "UPDATE currencies SET rate_to_myr = '4.7' WHERE code = 'USD'",
    );
    final row = await database
        .customSelect('SELECT * FROM transactions')
        .getSingle();
    expect(row.read<String>('currency_code'), 'USD');
    expect(row.read<int>('amount_minor'), 1250);
    expect(row.read<String>('exchange_rate_snapshot'), '4.5');
    expect(row.read<int>('amount_myr_minor'), 5625);
  });

  test('referenced parents cannot be deleted or reinterpreted', () async {
    await _addUsd(database);
    await _insert(database, currency: 'USD', rate: '4.5', myr: 5625);
    for (final statement in [
      "DELETE FROM categories WHERE id = 'seed-food'",
      "DELETE FROM currencies WHERE code = 'USD'",
      "UPDATE categories SET type = 'income' WHERE id = 'seed-food'",
      "UPDATE currencies SET decimal_places = 0 WHERE code = 'USD'",
      "UPDATE currencies SET code = 'USX' WHERE code = 'USD'",
    ]) {
      await expectLater(database.customStatement(statement), throwsException);
    }
    await database.customStatement(
      "UPDATE categories SET is_archived = 1 WHERE id = 'seed-food'",
    );
    await database.customStatement(
      "UPDATE currencies SET is_active = 0 WHERE code = 'USD'",
    );
    expect(
      await database.customSelect('SELECT * FROM transactions').get(),
      hasLength(1),
    );
  });

  test('failed transaction rolls back earlier writes', () async {
    await expectLater(
      database.transaction(() async {
        await database.customStatement(
          "INSERT INTO app_settings VALUES ('rollback-marker', 'test')",
        );
        await _insert(database, currency: 'BAD');
      }),
      throwsException,
    );
    expect(
      await database
          .customSelect(
            "SELECT * FROM app_settings WHERE key = 'rollback-marker'",
          )
          .get(),
      isEmpty,
    );
  });

  test(
    'file reopen preserves transactions and category edits without reseeding',
    () async {
      final directory = await Directory.systemTemp.createTemp('ledger-test-');
      final file = File('${directory.path}/ledger.sqlite');
      AppDatabase? disk;
      try {
        disk = AppDatabase.forTesting(NativeDatabase(file));
        await disk.initialize();
        await _insert(disk);
        await disk.customStatement(
          "UPDATE categories SET name = 'Meals' WHERE id = 'seed-food'",
        );
        await disk.customStatement(
          "DELETE FROM categories WHERE id = 'seed-bonus'",
        );
        await disk.close();
        disk = AppDatabase.forTesting(NativeDatabase(file));
        await disk.initialize();
        expect(
          await disk.customSelect('SELECT * FROM transactions').get(),
          hasLength(1),
        );
        final food = await disk
            .customSelect("SELECT name FROM categories WHERE id = 'seed-food'")
            .getSingle();
        expect(food.read<String>('name'), 'Meals');
        expect(
          await disk
              .customSelect("SELECT * FROM categories WHERE id = 'seed-bonus'")
              .get(),
          isEmpty,
        );
      } finally {
        await disk?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

Future<void> _addUsd(AppDatabase database) =>
    database.customStatement('''INSERT INTO currencies VALUES
     ('USD', 'US Dollar', '\$', 2, '4.5', 1, 0, 0)''');

Future<void> _insert(
  AppDatabase database, {
  String currency = 'MYR',
  String type = 'expense',
  int amount = 1250,
  String rate = '1',
  int myr = 1250,
  String date = '2026-11-05',
}) => database.customStatement(
  '''INSERT INTO transactions
     (id, category_id, type, amount_minor, currency_code,
      exchange_rate_snapshot, amount_myr_minor, transaction_date,
      created_at_utc, updated_at_utc)
     VALUES ('123e4567-e89b-42d3-a456-426614174000', 'seed-food', ?, ?, ?, ?, ?, ?, 0, 0)''',
  [type, amount, currency, rate, myr, date],
);
