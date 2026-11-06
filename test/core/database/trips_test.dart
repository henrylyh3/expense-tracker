import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:expense_tracker/core/backup/backup_service.dart';
import 'package:expense_tracker/core/backup/backup_validator.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/dates/calendar_date.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/core/providers/database_providers.dart';
import 'package:expense_tracker/core/providers/trip_provider.dart';
import 'package:expense_tracker/features/reports/data/report_repository.dart';
import 'package:expense_tracker/features/reports/domain/report_period.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/transaction_input.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'trips isolate expenses and rates across months and backup restore',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final trips = container.read(tripActionsProvider);
      await db.customStatement(
        "INSERT INTO currencies VALUES ('THB','Baht','THB',2,'0.13',1,0,0)",
      );
      await trips.create('Thailand December');
      await trips.create('Thailand April');
      Future<String> tripId(String name) async =>
          (await db
                  .customSelect(
                    'SELECT id FROM trips WHERE name = ?',
                    variables: [Variable.withString(name)],
                  )
                  .getSingle())
              .read<String>('id');
      final december = await tripId('Thailand December');
      final april = await tripId('Thailand April');
      await trips.setRate(december, 'THB', '0.12');
      await trips.setRate(april, 'THB', '0.14');

      final transactions = TransactionRepository(db);
      Future<String> add(String date) => transactions.save(
        TransactionInput(
          type: TransactionType.expense,
          categoryId: 'seed-food',
          currencyCode: 'THB',
          amountText: '100',
          date: CalendarDate.parse(date),
        ),
      );
      await trips.activate(december);
      final first = await add('2025-12-30');
      await add('2026-01-02');
      await trips.activate(april);
      final second = await add('2026-04-05');
      expect(
        (await transactions.getById(first)).conversion.exchangeRate,
        '0.12',
      );
      expect(
        (await transactions.getById(second)).conversion.exchangeRate,
        '0.14',
      );
      expect(
        (await transactions.watchHistory(tripId: april).first).single.id,
        second,
      );
      expect(await transactions.watchById(first, tripId: april).first, isNull);

      final reports = ReportRepository(db);
      final report = await reports
          .watchPeriod(ReportPeriod.trip(), tripId: december)
          .first;
      expect(report.expenseMinor, 2400);
      expect(report.buckets.map((bucket) => bucket.date.toString()), [
        '2025-12-30',
        '2026-01-02',
      ]);

      final bytes = await BackupService(db).exportBytes();
      final restored = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(restored.close);
      await restored.initialize();
      await BackupService(restored).restore(BackupValidator.decode(bytes));
      final restoredRepo = TransactionRepository(restored);
      expect(
        (await restoredRepo.watchHistory(tripId: december).first).length,
        2,
      );
      expect(
        (await restoredRepo.getById(second)).conversion.exchangeRate,
        '0.14',
      );
      final newExpense = await restoredRepo.save(
        TransactionInput(
          type: TransactionType.expense,
          categoryId: 'seed-food',
          currencyCode: 'THB',
          amountText: '50',
          date: CalendarDate.parse('2026-04-06'),
        ),
      );
      expect(
        (await restoredRepo.getById(newExpense)).conversion.myr.minorUnits,
        700,
      );
    },
  );
}
