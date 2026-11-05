import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/core/money/currency_catalog.dart';
import 'package:expense_tracker/core/money/exchange_rate.dart';
import 'package:expense_tracker/features/categories/domain/ledger_category.dart';
import 'package:expense_tracker/features/currencies/domain/configured_currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes decimal rates without binary floating point', () {
    expect(normalizeExchangeRate(' 4.5000 '), '4.5');
    expect(normalizeExchangeRate('0.000000000001'), '0.000000000001');
    expect(
      normalizeExchangeRate('999999999999.999999999999'),
      '999999999999.999999999999',
    );
  });

  test('rejects zero, negative, exponent, grouping and oversized rates', () {
    for (final value in [
      '',
      '0',
      '0.000',
      '-1',
      '1e2',
      '1,000',
      'NaN',
      '.5',
      '1.',
      '01.2',
      '1000000000000',
      '0.0000000000001',
    ]) {
      expect(
        () => normalizeExchangeRate(value),
        throwsA(isA<LedgerException>()),
        reason: value,
      );
    }
  });

  test('normalizes currency code and metadata', () {
    final draft = _currency(code: ' usd ', name: ' US Dollar ', rate: '4.50');
    expect(draft.code, 'USD');
    expect(draft.name, 'US Dollar');
    expect(draft.rateToMyr, '4.5');
  });

  test('accepts zero-decimal currencies and rejects unsupported precision', () {
    expect(_currency(code: 'JPY', precision: 0).decimalPlaces, 0);
    expect(_currency(code: 'KRW', precision: 0).decimalPlaces, 0);
    for (final precision in [-1, 7]) {
      expect(
        () => _currency(precision: precision),
        throwsA(isA<LedgerException>()),
      );
    }
  });

  test('enforces MYR identity and precision independently of the UI', () {
    expect(_currency(code: 'MYR', rate: '1.00').rateToMyr, '1');
    expect(
      () => _currency(code: 'MYR', rate: '4.5'),
      throwsA(isA<LedgerException>()),
    );
    expect(
      () => _currency(code: 'MYR', rate: '1', precision: 0),
      throwsA(isA<LedgerException>()),
    );
  });

  test('rejects invalid currency codes and missing metadata', () {
    for (final code in ['US', 'USDD', 'U1D', '美元']) {
      expect(() => _currency(code: code), throwsA(isA<LedgerException>()));
    }
    expect(() => _currency(name: ' '), throwsA(isA<LedgerException>()));
    expect(
      () => CurrencyDraft(
        code: 'USD',
        name: 'Dollar',
        symbol: ' ',
        decimalPlaces: 2,
        rateToMyr: '4.5',
      ),
      throwsA(isA<LedgerException>()),
    );
  });

  test('category drafts trim names and normalize hex colors', () {
    final draft = _category(name: ' Food ', color: '#aabbcc');
    expect(draft.name, 'Food');
    expect(draft.colorHex, '#AABBCC');
  });

  test('rejects invalid category names, colors and icon keys', () {
    expect(() => _category(name: ''), throwsA(isA<LedgerException>()));
    expect(
      () => _category(name: List.filled(81, 'a').join()),
      throwsA(isA<LedgerException>()),
    );
    for (final color in ['red', '#123', '#GGGGGG', '#FFFFFFFF']) {
      expect(() => _category(color: color), throwsA(isA<LedgerException>()));
    }
    expect(
      () => CategoryDraft(
        name: 'Food',
        type: TransactionType.expense,
        iconKey: '../icon',
        colorHex: '#123456',
      ),
      throwsA(isA<LedgerException>()),
    );
  });

  test('currency catalog supplies precision but no default exchange rates', () {
    expect(
      currencyCatalog.firstWhere((item) => item.code == 'JPY').decimalPlaces,
      0,
    );
    expect(
      currencyCatalog.firstWhere((item) => item.code == 'KRW').decimalPlaces,
      0,
    );
    expect(
      currencyCatalog.map((item) => item.code).toSet().length,
      currencyCatalog.length,
    );
  });

  test('only deliberate domain messages are shown to users', () {
    expect(
      ledgerErrorMessage(const LedgerException('Choose a currency.')),
      'Choose a currency.',
    );
    expect(
      ledgerErrorMessage(StateError('/private/financial.sqlite')),
      isNot(contains('/private/')),
    );
  });
}

CurrencyDraft _currency({
  String code = 'USD',
  String name = 'US Dollar',
  String rate = '4.5',
  int precision = 2,
}) => CurrencyDraft(
  code: code,
  name: name,
  symbol: r'$',
  decimalPlaces: precision,
  rateToMyr: rate,
);

CategoryDraft _category({String name = 'Food', String color = '#123456'}) =>
    CategoryDraft(
      name: name,
      type: TransactionType.expense,
      iconKey: 'restaurant',
      colorHex: color,
    );
