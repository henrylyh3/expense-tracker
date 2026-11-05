import 'package:decimal/decimal.dart';

import '../models/ledger_types.dart';

String normalizeExchangeRate(String input) {
  final value = input.trim();
  if (!RegExp(r'^(0|[1-9][0-9]{0,11})(\.[0-9]{1,12})?$').hasMatch(value)) {
    throw const LedgerException(
      'Enter a positive decimal rate, with up to 12 digits before and after the decimal point.',
    );
  }
  final decimal = Decimal.parse(value);
  if (decimal <= Decimal.zero) {
    throw const LedgerException('The exchange rate must be greater than zero.');
  }
  return decimal.toString();
}
