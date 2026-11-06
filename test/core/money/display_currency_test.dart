import 'package:expense_tracker/core/money/display_currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('display currency divides saved MYR by the configured rate', () {
    const usd = DisplayCurrency('USD', 2, '4.5');
    expect(usd.format(5625), 'USD 12.50');
    expect(usd.chartValue(5625), 12.5);
    expect(const DisplayCurrency('JPY', 0, '0.02').format(1), 'JPY 1');
    expect(const DisplayCurrency('KWD', 3, '10').format(125), 'KWD 0.125');
  });
}
