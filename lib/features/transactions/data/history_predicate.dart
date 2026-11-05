import '../domain/transaction_filter.dart';

/// SQL fragments are fixed application strings; all user input is bound.
class HistoryPredicate {
  const HistoryPredicate(this.sql, this.arguments);
  final String sql;
  final List<String> arguments;
}

HistoryPredicate buildHistoryPredicate(TransactionFilter filter) {
  final clauses = <String>[];
  final arguments = <String>[];
  void add(String sql, String? value) {
    if (value != null) {
      clauses.add(sql);
      arguments.add(value);
    }
  }

  add('t.type = ?', filter.type?.name);
  add('t.category_id = ?', filter.categoryId);
  add('t.currency_code = ?', filter.currencyCode);
  add('t.transaction_date >= ?', filter.from?.toString());
  add('t.transaction_date <= ?', filter.to?.toString());
  if (filter.query.isNotEmpty) {
    clauses.add(
      "(instr(lower(COALESCE(t.note, '')), lower(?)) > 0 OR instr(lower(c.name), lower(?)) > 0 OR instr(lower(t.currency_code), lower(?)) > 0)",
    );
    arguments.addAll([filter.query, filter.query, filter.query]);
  }
  return HistoryPredicate(
    clauses.isEmpty ? '' : ' WHERE ${clauses.join(' AND ')}',
    List.unmodifiable(arguments),
  );
}
