import '../models/ledger_types.dart';
import 'exchange_rate.dart';
import 'money.dart';

abstract final class CurrencyConverter {
  /// Round once, half up, to whole MYR sen. Decimal validates/canonicalizes the
  /// rate; BigInt numerator/denominator arithmetic makes ties explicit.
  static Money toMyr(Money amount, String exchangeRate) {
    if (amount.minorUnits <= 0) {
      throw const LedgerException(
        'The transaction amount must be greater than zero.',
      );
    }
    final rate = normalizeExchangeRate(exchangeRate);
    if (amount.currencyCode == 'MYR' && rate != '1') {
      throw const LedgerException('The MYR exchange rate must be 1.');
    }
    final parts = rate.split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    final coefficient = BigInt.parse('${parts[0]}$fraction');
    final numerator =
        BigInt.from(amount.minorUnits) * coefficient * BigInt.from(100);
    final denominator = BigInt.from(
      10,
    ).pow(amount.decimalPlaces + fraction.length);
    var rounded = numerator ~/ denominator;
    if (numerator.remainder(denominator) * BigInt.two >= denominator) {
      rounded += BigInt.one;
    }
    return Money.fromMinor(
      minorUnits: Money.checkedMinorUnits(rounded),
      currencyCode: 'MYR',
      decimalPlaces: 2,
    );
  }
}
