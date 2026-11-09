import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:expense_tracker/features/currencies/data/currency_repository.dart';
import 'package:expense_tracker/features/currencies/domain/configured_currency.dart';
import 'package:expense_tracker/core/backup/backup_service.dart';
import 'package:expense_tracker/core/backup/backup_validator.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/dates/calendar_date.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/core/providers/database_providers.dart';
import 'package:expense_tracker/core/providers/trip_provider.dart';
import 'package:expense_tracker/core/providers/default_currency_provider.dart';
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
      final currencies = CurrencyRepository(db);
      for (final entry in [('THB 2025', '0.12'), ('THB 2026', '0.14')]) {
        await currencies.save(
          CurrencyDraft(
            code: 'THB',
            name: entry.$1,
            symbol: 'THB',
            decimalPlaces: 2,
            rateToMyr: entry.$2,
          ),
        );
      }
      final records = await currencies.watchAll().first;
      final decemberRate = records.firstWhere(
        (item) => item.name == 'THB 2025',
      );
      final aprilRate = records.firstWhere((item) => item.name == 'THB 2026');
      await trips.setDefaultCurrency(december, decemberRate.key);

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
      await container.read(defaultCurrencyActionsProvider.notifier).set('MYR');
      await trips.setDefaultCurrency(april, aprilRate.key);
      final selected = container.listen(defaultCurrencyProvider, (_, _) {});
      final global = container.listen(globalDefaultCurrencyProvider, (_, _) {});
      expect(
        (await container.read(defaultCurrencyProvider.future)).code,
        'THB',
      );
      expect(
        (await container.read(globalDefaultCurrencyProvider.future)).code,
        'MYR',
      );
      selected.close();
      global.close();
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
      final used = container.listen(
        tripUsedCurrenciesProvider(april),
        (_, _) {},
      );
      expect(await container.read(tripUsedCurrenciesProvider(april).future), {
        'THB',
      });
      used.close();

      final reports = ReportRepository(db);
      final report = await reports
          .watchPeriod(ReportPeriod.trip(), tripId: december)
          .first;
      expect(report.expenseMinor, 2400);
      expect(report.buckets.map((bucket) => bucket.date.toString()), [
        '2025-12-30',
        '2026-01-02',
      ]);

      await trips.setRate(april, 'THB', '0.15', name: 'THB 2026');
      expect((await currencies.getByCode(aprilRate.key)).rateToMyr, '0.15');
      await currencies.save(
        CurrencyDraft(
          code: 'THB',
          name: 'THB 2026',
          symbol: 'THB',
          decimalPlaces: 2,
          rateToMyr: '0.16',
        ),
        originalCode: aprilRate.key,
      );
      final linkedRates = container.listen(tripRatesProvider(april), (_, _) {});
      expect(
        (await container.read(tripRatesProvider(april).future))['THB']!.rate,
        '0.16',
      );
      linkedRates.close();
      expect((await currencies.getByCode(decemberRate.key)).rateToMyr, '0.12');
      expect(
        (await transactions.getById(second)).conversion.exchangeRate,
        '0.14',
      );
      final bytes = await BackupService(db).exportBytes();
      final backup = BackupValidator.decode(bytes);
      final legacy = backup.toDocument();
      legacy['schema_version'] = 3;
      final legacyData = legacy['data'] as Map<String, Object?>;
      final legacyCounts = legacy['counts'] as Map<String, Object?>;
      legacyData.remove('currency_rates');
      legacyCounts.remove('currency_rates');
      for (final row in legacyData['trip_rates']! as List) {
        (row as Map).remove('rate_id');
      }
      for (final row in legacyData['transactions']! as List) {
        (row as Map).remove('amount_decimal_places');
      }
      final upgradedBackup = BackupValidator.fromDocument(legacy);
      expect(upgradedBackup.tables['currency_rates']!.length, 2);
      expect(
        backup.tables['settings']!.any(
          (row) =>
              row['key'] == 'trip_currency:$april' && row['value'] == 'THB',
        ),
        isTrue,
      );
      expect(
        backup.tables['trip_rates']!.map((row) => row['name']),
        unorderedEquals(['THB 2025', 'THB 2026']),
      );
      final restored = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(restored.close);
      await restored.initialize();
      await BackupService(restored).restore(backup);
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
        800,
      );
      await trips.delete(april);
      expect(await transactions.watchHistory(tripId: april).first, isEmpty);
      final moved =
          (await transactions.watchHistory(tripId: personalTripId).first)
              .single;
      expect(moved.id, second);
      expect(moved.conversion.exchangeRate, '0.14');
      final afterDeletion = await add('2026-04-07');
      expect(
        (await transactions.getById(afterDeletion)).conversion.exchangeRate,
        '0.13',
      );
      expect(
        (await transactions.watchHistory(tripId: personalTripId).first).length,
        2,
      );
    },
  );
}
