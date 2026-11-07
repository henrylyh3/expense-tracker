import 'package:decimal/decimal.dart';
import 'package:decimal/intl.dart';
import 'package:intl/intl.dart';

class DisplayCurrency {
  const DisplayCurrency(
    this.code,
    this.decimalPlaces,
    this.rateToMyr, {
    this.recordId,
  });
  static const myr = DisplayCurrency('MYR', 2, '1');

  final String? recordId;
  String get key => recordId ?? code;
  final String code;
  final int decimalPlaces;
  final String rateToMyr;

  // MYR minor units divided by MYR per unit. Round only for display.
  String format(int myrMinor) {
    final parts = rateToMyr.split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    final numerator =
        BigInt.from(myrMinor).abs() *
        BigInt.from(10).pow(decimalPlaces + fraction.length);
    final denominator = BigInt.parse('${parts[0]}$fraction') * BigInt.from(100);
    final rounded =
        (numerator * BigInt.two + denominator) ~/ (denominator * BigInt.two);
    final digits = rounded.toString().padLeft(decimalPlaces + 1, '0');
    final point = digits.length - decimalPlaces;
    final sign = myrMinor < 0 ? '-' : '';
    final amount = decimalPlaces == 0
        ? '$sign$digits'
        : '$sign${digits.substring(0, point)}.${digits.substring(point)}';
    return DecimalFormatter(
      NumberFormat.currency(
        locale: 'en_MY',
        name: code,
        symbol: code == 'MYR' ? 'RM ' : '$code ',
        decimalDigits: decimalPlaces,
      ),
    ).format(Decimal.parse(amount));
  }

  double chartValue(int myrMinor) => myrMinor / 100 / double.parse(rateToMyr);
}
