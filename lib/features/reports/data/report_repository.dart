import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/dates/calendar_date.dart';
import '../../../core/models/ledger_types.dart';
import '../domain/financial_report.dart';
import '../domain/report_period.dart';

class ReportRepository {
  ReportRepository(this._database);
  final AppDatabase _database;

  Stream<FinancialReport> watchPeriod(
    ReportPeriod period, {
    bool expensesOnly = false,
  }) {
    final end = period.endExclusive;
    // One bounded, consistent SQLite result drives totals, category groups and
    // trends. Integer SUM can overflow and TOTAL converts to floating point;
    // exact aggregation is deliberately performed in the pure domain layer.
    return _database
        .customSelect(
          '''SELECT t.type, t.amount_myr_minor, t.transaction_date, t.category_id,
        c.name AS category_name, c.color_hex, c.icon_key
        FROM transactions t JOIN categories c ON c.id = t.category_id
        WHERE t.transaction_date >= ?${end == null ? '' : ' AND t.transaction_date < ?'}${expensesOnly ? " AND t.type = 'expense'" : ''}''',
          variables: [
            Variable<String>(period.start.toString()),
            if (end != null) Variable<String>(end.toString()),
          ],
          readsFrom: {_database.transactions, _database.categories},
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
              ),
            ),
          ),
        );
  }
}
