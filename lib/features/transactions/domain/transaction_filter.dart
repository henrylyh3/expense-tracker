import '../../../core/dates/calendar_date.dart';
import '../../../core/models/ledger_types.dart';

class TransactionFilter {
  factory TransactionFilter({
    String query = '',
    TransactionType? type,
    String? categoryId,
    String? currencyCode,
    CalendarDate? from,
    CalendarDate? to,
  }) {
    final text = query.trim();
    final code = currencyCode?.trim().toUpperCase();
    final category = categoryId?.trim();
    if (text.runes.length > 200) {
      throw const LedgerException(
        'Search must contain at most 200 characters.',
      );
    }
    if (code != null && !RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
      throw const LedgerException('Choose a valid currency filter.');
    }
    if (category != null && category.isEmpty) {
      throw const LedgerException('Choose a valid category filter.');
    }
    if (from != null &&
        to != null &&
        from.toString().compareTo(to.toString()) > 0) {
      throw const LedgerException(
        'The start date cannot be after the end date.',
      );
    }
    return TransactionFilter._(text, type, category, code, from, to);
  }
  const TransactionFilter.empty() : this._('', null, null, null, null, null);
  const TransactionFilter._(
    this.query,
    this.type,
    this.categoryId,
    this.currencyCode,
    this.from,
    this.to,
  );
  final String query;
  final TransactionType? type;
  final String? categoryId;
  final String? currencyCode;
  final CalendarDate? from;
  final CalendarDate? to;
  bool get hasConstraints => query.isNotEmpty || fieldCount > 0;
  int get fieldCount =>
      (type == null ? 0 : 1) +
      (categoryId == null ? 0 : 1) +
      (currencyCode == null ? 0 : 1) +
      (from == null && to == null ? 0 : 1);
  TransactionFilter withQuery(String value) => TransactionFilter(
    query: value,
    type: type,
    categoryId: categoryId,
    currencyCode: currencyCode,
    from: from,
    to: to,
  );

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      query == other.query &&
      type == other.type &&
      categoryId == other.categoryId &&
      currencyCode == other.currencyCode &&
      from == other.from &&
      to == other.to;
  @override
  int get hashCode =>
      Object.hash(query, type, categoryId, currencyCode, from, to);
}
