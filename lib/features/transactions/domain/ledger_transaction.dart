import '../../../core/dates/calendar_date.dart';
import '../../../core/models/ledger_types.dart';
import 'conversion_policy.dart';

/// History/detail projection. Original monetary facts are separate from current
/// category display metadata and current currency active/archived status.
class LedgerTransaction {
  const LedgerTransaction({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIconKey,
    required this.categoryColorHex,
    required this.categoryArchived,
    required this.currencyActive,
    required this.type,
    required this.conversion,
    required this.date,
    required this.note,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  final String id;
  final String categoryId;
  final String categoryName;
  final String categoryIconKey;
  final String categoryColorHex;
  final bool categoryArchived;
  final bool currencyActive;
  final TransactionType type;
  final ConversionSnapshot conversion;
  final CalendarDate date;
  final String? note;
  final int createdAtUtc;
  final int updatedAtUtc;
}
