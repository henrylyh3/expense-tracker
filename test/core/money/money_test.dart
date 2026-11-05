import 'dart:math';

import 'package:expense_tracker/core/dates/calendar_date.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/core/money/currency_converter.dart';
import 'package:expense_tracker/core/money/money.dart';
import 'package:expense_tracker/features/transactions/domain/conversion_policy.dart';
import 'package:expense_tracker/features/transactions/domain/transaction_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses original amounts with currency-specific precision', () {
    for (final (code, precision, text, minor) in [
      ('MYR', 2, '12.50', 1250),
      ('USD', 2, '12.50', 1250),
      ('JPY', 0, '500', 500),
      ('KRW', 0, '15000', 15000),
    ]) {
      final money = _parse(text, code: code, precision: precision);
      expect(money.currencyCode, code);
      expect(money.minorUnits, minor);
      expect(money.toInput(), text);
    }
  });

  test(
    'rejects zero, negatives, signs, grouping, exponent and non-numeric amounts',
    () {
      for (final value in [
        '0',
        '0.00',
        '-1',
        '+1',
        '1,000',
        '1e3',
        'NaN',
        '.5',
        '1.',
        'abc',
      ]) {
        expect(
          () => _parse(value),
          throwsA(isA<LedgerException>()),
          reason: value,
        );
      }
    },
  );

  test('rejects excess precision even when the extra digits are zero', () {
    expect(() => _parse('12.500'), throwsA(isA<LedgerException>()));
    expect(
      () => _parse('500.0', code: 'JPY', precision: 0),
      throwsA(isA<LedgerException>()),
    );
    expect(_parse('00012.5').toInput(), '12.50');
  });

  test('checks minor-unit bounds before narrowing BigInt to int', () {
    expect(
      _parse('92233720368547758.07').minorUnits,
      Money.maxMinorUnits.toInt(),
    );
    expect(
      () => _parse('92233720368547758.08'),
      throwsA(isA<LedgerException>()),
    );
    expect(
      () => _parse('9223372036854775808', code: 'JPY', precision: 0),
      throwsA(isA<LedgerException>()),
    );
  });

  test('formatting preserves cents at the signed 64-bit boundary', () {
    final maximum = _parse('92233720368547758.07');
    expect(maximum.format(), contains('92,233,720,368,547,758.07'));
    final minimum = Money.fromMinor(
      minorUnits: Money.minMinorUnits.toInt(),
      currencyCode: 'MYR',
      decimalPlaces: 2,
    );
    expect(minimum.toInput(), '-92233720368547758.08');
    expect(minimum.format(), contains('92,233,720,368,547,758.08'));
  });

  test('converts USD 12.50 at 4.50 to MYR 56.25', () {
    final converted = CurrencyConverter.toMyr(_parse('12.50'), '4.50');
    expect(converted.minorUnits, 5625);
    expect(converted.currencyCode, 'MYR');
  });

  test('converts zero-decimal JPY and KRW correctly', () {
    expect(
      CurrencyConverter.toMyr(
        _parse('500', code: 'JPY', precision: 0),
        '0.03',
      ).minorUnits,
      1500,
    );
    expect(
      CurrencyConverter.toMyr(
        _parse('15000', code: 'KRW', precision: 0),
        '0.0034',
      ).minorUnits,
      5100,
    );
  });

  test('rounds half up once to whole sen', () {
    for (final (rate, minor) in [
      ('0.49', 0),
      ('0.5', 1),
      ('1.5', 2),
      ('2.5', 3),
    ]) {
      expect(CurrencyConverter.toMyr(_parse('0.01'), rate).minorUnits, minor);
    }
    expect(
      CurrencyConverter.toMyr(
        _parse('1', code: 'JPY', precision: 0),
        '0.000000000001',
      ).minorUnits,
      0,
    );
  });

  test('rejects invalid MYR conversion and converted amount overflow', () {
    expect(
      () => CurrencyConverter.toMyr(_parse('1', code: 'MYR'), '2'),
      throwsA(isA<LedgerException>()),
    );
    expect(
      () => CurrencyConverter.toMyr(
        _parse('9223372036854775807', code: 'JPY', precision: 0),
        '1',
      ),
      throwsA(isA<LedgerException>()),
    );
  });

  test('large intermediate products do not overflow before division', () {
    expect(
      CurrencyConverter.toMyr(_parse('92233720368547758.07'), '1').minorUnits,
      Money.maxMinorUnits.toInt(),
    );
  });

  test('MYR identity holds over varied amounts', () {
    final random = Random(42);
    for (var i = 0; i < 250; i++) {
      final minor = random.nextInt(1000000000) + 1;
      final amount = Money.fromMinor(
        minorUnits: minor,
        currencyCode: 'MYR',
        decimalPlaces: 2,
      );
      expect(CurrencyConverter.toMyr(amount, '1').minorUnits, minor);
    }
  });

  test('ordinary edits preserve both historical conversion facts exactly', () {
    final saved = _saved();
    final result = resolveConversion(
      original: _parse('12.50'),
      defaultRate: '4.7',
      previous: saved,
    );
    expect(identical(result, saved), isTrue);
    expect(result.exchangeRate, '4.5000');
    expect(result.myr.minorUnits, 5625);
  });

  test(
    'amount edits use the saved rate and explicit rate edits recalculate',
    () {
      final amountEdit = resolveConversion(
        original: _parse('20'),
        defaultRate: '4.7',
        previous: _saved(),
      );
      expect(amountEdit.exchangeRate, '4.5');
      expect(amountEdit.myr.minorUnits, 9000);
      final rateEdit = resolveConversion(
        original: _parse('12.50'),
        defaultRate: '4.7',
        previous: _saved(),
        rateOverride: '4.7',
      );
      expect(rateEdit.myr.minorUnits, 5875);
    },
  );

  test('currency changes require confirmation of an explicit rate', () {
    final jpy = _parse('500', code: 'JPY', precision: 0);
    expect(
      () => resolveConversion(
        original: jpy,
        defaultRate: '0.03',
        previous: _saved(),
      ),
      throwsA(isA<LedgerException>()),
    );
    expect(
      () => resolveConversion(
        original: jpy,
        defaultRate: '0.03',
        previous: _saved(),
        currencyChangeConfirmed: true,
      ),
      throwsA(isA<LedgerException>()),
    );
    final changed = resolveConversion(
      original: jpy,
      defaultRate: '0.04',
      previous: _saved(),
      rateOverride: '0.03',
      currencyChangeConfirmed: true,
    );
    expect(changed.myr.minorUnits, 1500);
  });

  test('new transactions use configured defaults or an explicit override', () {
    expect(
      resolveConversion(
        original: _parse('12.50'),
        defaultRate: '4.5',
      ).myr.minorUnits,
      5625,
    );
    expect(
      resolveConversion(
        original: _parse('12.50'),
        defaultRate: '4.5',
        rateOverride: '4.7',
      ).myr.minorUnits,
      5875,
    );
  });

  test('rejects reinterpretation of saved currency precision', () {
    expect(
      () => resolveConversion(
        original: _parse('12', precision: 0),
        defaultRate: '4.5',
        previous: _saved(),
      ),
      throwsA(isA<LedgerException>()),
    );
  });

  test(
    'calendar dates validate leap years and boundaries without time-zone conversion',
    () {
      for (final date in [
        '0001-01-01',
        '2000-02-29',
        '2024-02-29',
        '9999-12-31',
      ]) {
        expect(CalendarDate.parse(date).toString(), date);
      }
      for (final date in [
        '0000-01-01',
        '1900-02-29',
        '2026-02-29',
        '2026-04-31',
        '2026-1-01',
      ]) {
        expect(() => CalendarDate.parse(date), throwsA(isA<LedgerException>()));
      }
      expect(
        CalendarDate.fromDateTime(DateTime.utc(2026, 11, 5, 23, 59)).toString(),
        '2026-11-05',
      );
    },
  );

  test('transaction notes are optional, bounded and may contain newlines', () {
    expect(TransactionInput.normalizeNote('   '), isNull);
    expect(
      TransactionInput.normalizeNote(' line 1\nline 2 '),
      'line 1\nline 2',
    );
    expect(
      () => TransactionInput.normalizeNote(List.filled(2001, 'a').join()),
      throwsA(isA<LedgerException>()),
    );
    expect(
      () => TransactionInput.normalizeNote('a\u0000b'),
      throwsA(isA<LedgerException>()),
    );
  });
}

Money _parse(String text, {String code = 'USD', int precision = 2}) =>
    Money.parsePositive(text, currencyCode: code, decimalPlaces: precision);
ConversionSnapshot _saved() => ConversionSnapshot(
  original: _parse('12.50'),
  exchangeRate: '4.5000',
  myr: Money.fromMinor(minorUnits: 5625, currencyCode: 'MYR', decimalPlaces: 2),
);
