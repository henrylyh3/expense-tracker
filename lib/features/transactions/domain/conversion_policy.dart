import '../../../core/models/ledger_types.dart';
import '../../../core/money/currency_converter.dart';
import '../../../core/money/exchange_rate.dart';
import '../../../core/money/money.dart';

class ConversionSnapshot {
  const ConversionSnapshot({
    required this.original,
    required this.exchangeRate,
    required this.myr,
  });
  final Money original;
  final String exchangeRate;
  final Money myr;
}

ConversionSnapshot resolveConversion({
  required Money original,
  required String defaultRate,
  ConversionSnapshot? previous,
  String? rateOverride,
  bool currencyChangeConfirmed = false,
}) {
  if (previous != null &&
      previous.original.currencyCode != original.currencyCode &&
      (!currencyChangeConfirmed || rateOverride == null)) {
    throw const LedgerException(
      'Confirm the new currency and its exchange rate before saving.',
    );
  }
  final sameCurrency = previous?.original.currencyCode == original.currencyCode;
  if (sameCurrency &&
      rateOverride == null &&
      BigInt.from(previous!.original.minorUnits) *
              BigInt.from(10).pow(original.decimalPlaces) ==
          BigInt.from(original.minorUnits) *
              BigInt.from(10).pow(previous.original.decimalPlaces)) {
    // Notes/date/category edits must retain both stored conversion facts exactly.
    return previous;
  }
  final rate = normalizeExchangeRate(
    rateOverride ?? (sameCurrency ? previous!.exchangeRate : defaultRate),
  );
  return ConversionSnapshot(
    original: original,
    exchangeRate: rate,
    myr: CurrencyConverter.toMyr(original, rate),
  );
}
