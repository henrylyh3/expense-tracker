/// Suggestions only. No exchange rates are invented or downloaded.
class CurrencySuggestion {
  const CurrencySuggestion(
    this.code,
    this.name,
    this.symbol,
    this.decimalPlaces,
  );
  final String code;
  final String name;
  final String symbol;
  final int decimalPlaces;
}

const currencyCatalog = [
  CurrencySuggestion('USD', 'US Dollar', r'$', 2),
  CurrencySuggestion('JPY', 'Japanese Yen', '¥', 0),
  CurrencySuggestion('KRW', 'South Korean Won', '₩', 0),
  CurrencySuggestion('SGD', 'Singapore Dollar', r'S$', 2),
  CurrencySuggestion('EUR', 'Euro', '€', 2),
  CurrencySuggestion('THB', 'Thai Baht', '฿', 2),
  CurrencySuggestion('TWD', 'New Taiwan Dollar', r'NT$', 2),
  CurrencySuggestion('IDR', 'Indonesian Rupiah', 'Rp', 2),
];
