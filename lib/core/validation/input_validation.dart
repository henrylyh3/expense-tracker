import '../models/ledger_types.dart';

String requiredText(
  String input, {
  required String label,
  required int maxLength,
}) {
  final value = input.trim();
  if (value.isEmpty || value.runes.length > maxLength) {
    throw LedgerException('$label must contain 1–$maxLength characters.');
  }
  return value;
}

/// Adapts the same domain validation used by repositories to Flutter forms.
String? fieldError(void Function() validate) {
  try {
    validate();
    return null;
  } on LedgerException catch (error) {
    return error.message;
  }
}
