import '../../../core/dates/calendar_date.dart';
import '../../../core/models/ledger_types.dart';
import '../../../core/money/exchange_rate.dart';
import '../../../core/validation/input_validation.dart';

class TransactionInput {
  TransactionInput({
    required this.type,
    required String categoryId,
    required String currencyCode,
    required String amountText,
    required this.date,
    this.targetTripId,
    String? note,
    String? rateOverride,
    this.currencyChangeConfirmed = false,
  }) : categoryId = requiredText(categoryId, label: 'Category', maxLength: 64),
       currencyCode = currencyCode.trim().toUpperCase(),
       amountText = requiredText(amountText, label: 'Amount', maxLength: 40),
       note = normalizeNote(note),
       rateOverride = rateOverride == null
           ? null
           : normalizeExchangeRate(rateOverride) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(this.currencyCode)) {
      throw const LedgerException('Choose a valid currency.');
    }
  }

  final TransactionType type;
  final String categoryId;
  final String currencyCode;
  final String amountText;
  final CalendarDate date;
  final String? targetTripId;
  final String? note;
  final String? rateOverride;
  final bool currencyChangeConfirmed;

  static String? normalizeNote(String? value) {
    final note = value?.trim();
    if (note == null || note.isEmpty) return null;
    if (note.runes.length > 2000 || note.contains('\u0000')) {
      throw const LedgerException(
        'Notes must contain at most 2000 characters and no null characters.',
      );
    }
    return note;
  }
}
