import '../../../core/models/ledger_types.dart';
import '../../../core/money/exchange_rate.dart';
import '../../../core/validation/input_validation.dart';

class ConfiguredCurrency {
  const ConfiguredCurrency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimalPlaces,
    required this.rateToMyr,
    required this.isActive,
    required this.usageCount,
  });

  final String code;
  final String name;
  final String symbol;
  final int decimalPlaces;
  final String rateToMyr;
  final bool isActive;
  final int usageCount;
  bool get isBase => code == 'MYR';
  bool get isUsed => usageCount > 0;
}

class CurrencyDraft {
  CurrencyDraft({
    required String code,
    required String name,
    required String symbol,
    required this.decimalPlaces,
    required String rateToMyr,
  }) : code = validateCode(code),
       name = requiredText(name, label: 'Currency name', maxLength: 80),
       symbol = requiredText(symbol, label: 'Symbol', maxLength: 12),
       rateToMyr = normalizeExchangeRate(rateToMyr) {
    if (decimalPlaces < 0 || decimalPlaces > 6) {
      throw const LedgerException('Decimal places must be between 0 and 6.');
    }
    if (this.code == 'MYR' && (decimalPlaces != 2 || this.rateToMyr != '1')) {
      throw const LedgerException(
        'MYR must use 2 decimal places and a rate of 1.',
      );
    }
  }

  final String code;
  final String name;
  final String symbol;
  final int decimalPlaces;
  final String rateToMyr;

  static String validateCode(String input) {
    final value = input.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(value)) {
      throw const LedgerException(
        'Use a three-letter currency code, such as USD.',
      );
    }
    return value;
  }
}
