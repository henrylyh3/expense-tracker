import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/dates/calendar_date.dart';
import '../../../core/models/ledger_types.dart';
import '../../../core/money/money.dart';
import '../domain/financial_report.dart';
import '../domain/report_period.dart';

class ReportRepository {
  ReportRepository(this._database);
  final AppDatabase _database;

  Stream<FinancialReport> watchPeriod(
    ReportPeriod period, {
    bool expensesOnly = false,
    String? tripId,
    bool includeCurrencyTotals = false,
  }) {
    final end = period.endExclusive;
    // One bounded, consistent SQLite result drives totals, category groups and
    // trends. Integer SUM can overflow and TOTAL converts to floating point;
    // exact aggregation is deliberately performed in the pure domain layer.
    return _database
        .customSelect(
          '''SELECT t.type, t.amount_myr_minor, t.transaction_date, t.category_id,
        c.name AS category_name, c.color_hex, c.icon_key,
        t.amount_minor, t.currency_code, currency.decimal_places, t.exchange_rate_snapshot
        FROM transactions t JOIN categories c ON c.id = t.category_id
        JOIN currencies currency ON currency.code = t.currency_code
        WHERE t.transaction_date >= ?${end == null ? '' : ' AND t.transaction_date < ?'}${expensesOnly ? " AND t.type = 'expense'" : ''}${tripId == null ? '' : ' AND t.trip_id = ?'}''',
          variables: [
            Variable<String>(period.start.toString()),
            if (end != null) Variable<String>(end.toString()),
            if (tripId != null) Variable.withString(tripId),
          ],
          readsFrom: {
            _database.transactions,
            _database.categories,
            _database.currencies,
          },
        )
        .watch()
        .map(
          (rows) => FinancialReport.calculate(
            period,
            rows.map(
              (row) => ReportEntry(
                type: TransactionType.values.byName(row.read<String>('type')),
                amountMyrMinor: row.read<int>('amount_myr_minor'),
                date: CalendarDate.parse(row.read<String>('transaction_date')),
                categoryId: row.read<String>('category_id'),
                categoryName: row.read<String>('category_name'),
                categoryColorHex: row.read<String>('color_hex'),
                categoryIconKey: row.read<String>('icon_key'),
                exchangeRate: includeCurrencyTotals
                    ? row.read<String>('exchange_rate_snapshot')
                    : null,
                original: includeCurrencyTotals
                    ? Money.fromMinor(
                        minorUnits: row.read<int>('amount_minor'),
                        currencyCode: row.read<String>('currency_code'),
                        decimalPlaces: row.read<int>('decimal_places'),
                      )
                    : null,
              ),
            ),
          ),
        );
  }
}
