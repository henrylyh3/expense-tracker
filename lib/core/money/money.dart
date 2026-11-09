import 'package:decimal/decimal.dart';
import 'package:decimal/intl.dart';
import 'package:intl/intl.dart';

import '../models/ledger_types.dart';

/// An exact, currency-qualified amount. No binary floating-point arithmetic.
class Money {
  Money.fromMinor({
    required this.minorUnits,
    required this.currencyCode,
    required this.decimalPlaces,
  }) {
    _validateCurrency(currencyCode, decimalPlaces);
    checkedMinorUnits(BigInt.from(minorUnits));
  }

  factory Money.parsePositive(
    String input, {
    required String currencyCode,
    required int decimalPlaces,
  }) {
    _validateCurrency(currencyCode, decimalPlaces);
    final value = input.trim();
    if (value.length > 40 || !RegExp(r'^[0-9]+(\.[0-9]+)?$').hasMatch(value)) {
      throw const LedgerException(
        'Enter an amount using digits and a decimal point, without grouping or a sign.',
      );
    }
    final parts = value.split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    if (fraction.length > decimalPlaces) {
      throw LedgerException(
        '$currencyCode supports $decimalPlaces decimal places.',
      );
    }
    final minor = BigInt.parse(
      '${parts[0]}${fraction.padRight(decimalPlaces, '0')}',
    );
    if (minor <= BigInt.zero) {
      throw const LedgerException(
        'The transaction amount must be greater than zero.',
      );
    }
    return Money.fromMinor(
      minorUnits: checkedMinorUnits(minor),
      currencyCode: currencyCode,
      decimalPlaces: decimalPlaces,
    );
  }

  final int minorUnits;

  /// Expense entry accepts fractional foreign amounts regardless of ISO units.
  factory Money.parseExpense(
    String input, {
    required String currencyCode,
    required int decimalPlaces,
  }) {
    final parts = input.trim().split('.');
    final fraction = parts.length == 2 ? parts.last.length : 0;
    final precision = currencyCode == 'MYR'
        ? 2
        : (fraction > decimalPlaces ? fraction : decimalPlaces);
    if (precision > 6) {
      throw const LedgerException(
        'Use up to 6 decimal places for an expense amount.',
      );
    }
    return Money.parsePositive(
      input,
      currencyCode: currencyCode,
      decimalPlaces: precision,
    );
  }
  final String currencyCode;
  final int decimalPlaces;

  static final maxMinorUnits = BigInt.parse('9223372036854775807');
  static final minMinorUnits = BigInt.parse('-9223372036854775808');

  static int checkedMinorUnits(BigInt value) {
    if (value < minMinorUnits || value > maxMinorUnits) {
      throw const LedgerException(
        'The amount exceeds the supported 64-bit range.',
      );
    }
    return value.toInt();
  }

  /// Canonical editor/backup representation, without grouping or exponent.
  String toInput() {
    final digits = BigInt.from(
      minorUnits,
    ).abs().toString().padLeft(decimalPlaces + 1, '0');
    final sign = minorUnits < 0 ? '-' : '';
    if (decimalPlaces == 0) return '$sign$digits';
    final point = digits.length - decimalPlaces;
    return '$sign${digits.substring(0, point)}.${digits.substring(point)}';
  }

  String format({String locale = 'en_MY'}) => DecimalFormatter(
    NumberFormat.currency(
      locale: locale,
      name: currencyCode,
      symbol: currencyCode == 'MYR' ? 'RM ' : '$currencyCode ',
      decimalDigits: decimalPlaces,
    ),
  ).format(Decimal.parse(toInput()));

  static void _validateCurrency(String code, int precision) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(code) ||
        precision < 0 ||
        precision > 6 ||
        (code == 'MYR' && precision != 2)) {
      throw const LedgerException(
        'Invalid currency code or decimal precision.',
      );
    }
  }
}
