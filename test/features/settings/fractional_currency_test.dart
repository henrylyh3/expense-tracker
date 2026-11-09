import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/dates/calendar_date.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/core/backup/backup_service.dart';
import 'package:expense_tracker/core/backup/backup_validator.dart';
import 'package:expense_tracker/features/currencies/data/currency_repository.dart';
import 'package:expense_tracker/features/currencies/domain/configured_currency.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/transaction_input.dart';
import 'package:expense_tracker/features/reports/data/report_repository.dart';
import 'package:expense_tracker/features/reports/domain/report_period.dart';
import 'package:flutter_test/flutter_test.dart';

CurrencyDraft draft(String name, {String code = 'JPY'}) => CurrencyDraft(
  code: code,
  name: name,
  symbol: code,
  decimalPlaces: 0,
  rateToMyr: '0.03',
);
void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.initialize();
  });
  tearDown(() => db.close());
  test(
    'fractional JPY survives history, mixed-scale reports and backup restore',
    () async {
      await CurrencyRepository(db).save(draft('Yen'));
      final repo = TransactionRepository(db);
      Future<String> add(String amount) => repo.save(
        TransactionInput(
          type: TransactionType.expense,
          categoryId: 'seed-food',
          currencyCode: 'JPY',
          amountText: amount,
          date: CalendarDate.parse('2026-11-09'),
        ),
      );
      final whole = await add('100');
      final fractional = await add('0.125');
      expect((await repo.getById(whole)).conversion.original.toInput(), '100');
      expect(
        (await repo.getById(fractional)).conversion.original.toInput(),
        '0.125',
      );
      final report = await ReportRepository(db)
          .watchPeriod(
            ReportPeriod.trip(),
            tripId: 'personal',
            includeCurrencyTotals: true,
          )
          .first;
      expect(report.currencyTotals.single.toInput(), '100.125');
      final service = BackupService(db);
      final backup = BackupValidator.decode(await service.exportBytes());
      expect(backup.toDocument()['schema_version'], 5);
      await service.restore(backup);
      expect(
        (await repo.getById(fractional)).conversion.original.toInput(),
        '0.125',
      );
      expect(
        (await db
                .customSelect(
                  "SELECT decimal_places FROM currencies WHERE code='JPY'",
                )
                .getSingle())
            .read<int>('decimal_places'),
        0,
      );
    },
  );
  test('currency names are unique across base and named records', () async {
    final repo = CurrencyRepository(db);
    await repo.save(draft('THB 2025'));
    await expectLater(
      repo.save(draft(' thb   2025 ')),
      throwsA(isA<LedgerException>()),
    );
    await repo.save(draft('THB 2026'));
    final all = await repo.watchAll().first;
    final named = all.singleWhere((r) => r.recordId != null);
    await expectLater(
      repo.save(draft('THB 2025'), originalCode: named.key),
      throwsA(isA<LedgerException>()),
    );
    await repo.save(draft('THB 2026'), originalCode: named.key);
    await expectLater(
      repo.save(draft('THB 2026', code: 'KRW')),
      throwsA(isA<LedgerException>()),
    );
  });
}
