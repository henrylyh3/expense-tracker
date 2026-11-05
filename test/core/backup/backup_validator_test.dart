import 'dart:convert';
import 'dart:typed_data';

import 'package:expense_tracker/core/backup/backup_reader.dart';
import 'package:expense_tracker/core/backup/backup_validator.dart';
import 'package:expense_tracker/core/backup/restore_plan.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/backup_fixture.dart';

void main() {
  Uint8List bytes(String source) => Uint8List.fromList(utf8.encode(source));
  final invalid = throwsA(isA<LedgerException>());
  test(
    'round trip preserves historical rates, originals, archives and settings',
    () {
      final backup = BackupValidator.fromDocument(backupDocument());
      final restored = BackupValidator.decode(backup.encode());
      expect(restored.toDocument(), backupDocument());
      expect(
        restored.tables['transactions']!.single['exchange_rate_snapshot'],
        '4.5000',
      );
      expect(restored.tables['currencies']!.last['rate_to_myr'], '4.70');
      expect(restored.firstTransactionDate, '2026-11-04');
      expect(restored.lastTransactionDate, '2026-11-04');
      expect(
        () => restored.tables['transactions']!.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => restored.tables['transactions']!.single['amount_minor'] = 1,
        throwsUnsupportedError,
      );
    },
  );
  test('native database rows re-export without losing integer precision', () {
    final document = backupDocument();
    final row = document['data']['transactions'][0];
    row['currency_code'] = 'MYR';
    row['exchange_rate_snapshot'] = '1';
    row['amount_minor'] = '9223372036854775807';
    row['amount_myr_minor'] = row['amount_minor'];
    final backup = BackupValidator.fromDocument(document);
    final exported = BackupValidator.fromDatabaseRows(
      tables: backup.tables,
      appVersion: backup.appVersion,
      exportedAtUtc: backup.exportedAtUtc,
    );
    expect(BackupValidator.decode(exported.encode()).toDocument(), document);
  });
  test('background decoding uses sendable values', () async {
    final backup = await BackupValidator.decodeInBackground(
      bytes(jsonEncode(backupDocument())),
    );
    final snapshot = await BackupValidator.snapshotInBackground(
      tables: backup.tables,
      exportedAtUtc: backup.exportedAtUtc,
      appVersion: backup.appVersion,
    );
    expect(snapshot.toDocument(), backup.toDocument());
  });
  final mutations = <String, void Function(Map<String, dynamic>)>{
    'future format': (d) => d['format_version'] = 2,
    'fractional version': (d) => d['schema_version'] = 1.0,
    'wrong base': (d) => d['base_currency'] = 'USD',
    'unknown root field': (d) => d['extra'] = 1,
    'missing table': (d) => d['data'].remove('settings'),
    'wrong count': (d) => d['counts']['transactions'] = 0,
    'fractional count': (d) => d['counts']['categories'] = 1.0,
    'noncanonical timestamp': (d) =>
        d['exported_at_utc'] = '2026-11-05T10:00:00Z',
    'normalized impossible timestamp': (d) =>
        d['exported_at_utc'] = '2026-02-30T10:00:00.000Z',
    'missing MYR': (d) {
      d['data']['currencies'].removeAt(0);
      d['counts']['currencies'] = 1;
    },
    'inactive MYR': (d) => d['data']['currencies'][0]['is_active'] = false,
    'MYR default rate': (d) =>
        d['data']['currencies'][0]['rate_to_myr'] = '1.0',
    'MYR precision': (d) => d['data']['currencies'][0]['decimal_places'] = 0,
    'precision as double': (d) =>
        d['data']['currencies'][1]['decimal_places'] = 2.0,
    'excess precision': (d) => d['data']['currencies'][1]['decimal_places'] = 7,
    'invalid rate': (d) => d['data']['currencies'][1]['rate_to_myr'] = '4e1',
    'zero snapshot': (d) =>
        d['data']['transactions'][0]['exchange_rate_snapshot'] = '0',
    'missing category': (d) =>
        d['data']['transactions'][0]['category_id'] = 'missing',
    'missing currency': (d) =>
        d['data']['transactions'][0]['currency_code'] = 'EUR',
    'type mismatch': (d) => d['data']['transactions'][0]['type'] = 'income',
    'wrong equivalent': (d) =>
        d['data']['transactions'][0]['amount_myr_minor'] = '5875',
    'numeric amount': (d) =>
        d['data']['transactions'][0]['amount_minor'] = 1250,
    'leading zero amount': (d) =>
        d['data']['transactions'][0]['amount_minor'] = '01250',
    'negative amount': (d) =>
        d['data']['transactions'][0]['amount_minor'] = '-1',
    'zero amount': (d) => d['data']['transactions'][0]['amount_minor'] = '0',
    '64-bit overflow': (d) =>
        d['data']['transactions'][0]['amount_minor'] = '9223372036854775808',
    'invalid date': (d) =>
        d['data']['transactions'][0]['transaction_date'] = '2026-02-29',
    'date with time': (d) => d['data']['transactions'][0]['transaction_date'] =
        '2026-11-04T00:00:00',
    'invalid UUID': (d) => d['data']['transactions'][0]['id'] = 'test',
    'extra row field': (d) =>
        d['data']['transactions'][0]['account'] = 'wallet',
    'long note': (d) => d['data']['transactions'][0]['note'] = 'a' * 2001,
    'NUL in note': (d) => d['data']['transactions'][0]['note'] = '\u0000',
    'bad Unicode': (d) =>
        d['data']['transactions'][0]['note'] = String.fromCharCode(0xD800),
    'update before creation': (d) =>
        d['data']['transactions'][0]['created_at_utc'] = '2',
    'out of range audit': (d) =>
        d['data']['transactions'][0]['updated_at_utc'] = '253402300800000',
    'archive flag as integer': (d) =>
        d['data']['categories'][0]['is_archived'] = 1,
    'negative sort': (d) => d['data']['categories'][0]['sort_order'] = '-1',
    'invalid icon': (d) => d['data']['categories'][0]['icon_key'] = '../file',
    'invalid color': (d) => d['data']['categories'][0]['color_hex'] = '#GG0000',
    'unknown setting': (d) => d['data']['settings'][0]['key'] = 'other',
    'unknown theme': (d) => d['data']['settings'][0]['value'] = 'blue',
    'missing theme': (d) {
      d['data']['settings'].clear();
      d['counts']['settings'] = 0;
    },
  };
  for (final mutation in mutations.entries) {
    test('rejects ${mutation.key}', () {
      final document = backupDocument();
      mutation.value(document);
      expect(() => BackupValidator.fromDocument(document), invalid);
    });
  }
  for (final name in ['categories', 'currencies', 'transactions', 'settings']) {
    test('rejects duplicate $name', () {
      final document = backupDocument();
      document['data'][name].add(
        Map<String, dynamic>.from(
          document['data'][name].last as Map<String, dynamic>,
        ),
      );
      document['counts'][name]++;
      expect(() => BackupValidator.fromDocument(document), invalid);
    });
  }
  test('zero-decimal precision, half-up rounding and zero equivalents', () {
    final document = backupDocument();
    final currency = document['data']['currencies'][1];
    final row = document['data']['transactions'][0];
    currency['code'] = row['currency_code'] = 'JPY';
    currency['decimal_places'] = 0;
    row['amount_minor'] = '1';
    row['exchange_rate_snapshot'] = '0.005';
    row['amount_myr_minor'] = '1';
    expect(BackupValidator.fromDocument(document).count('transactions'), 1);
    row['exchange_rate_snapshot'] = '0.0001';
    row['amount_myr_minor'] = '0';
    expect(BackupValidator.fromDocument(document).count('transactions'), 1);
  });
  test('empty ledger is valid and has no date bounds', () {
    final document = backupDocument();
    for (final name in ['transactions', 'categories']) {
      document['data'][name].clear();
      document['counts'][name] = 0;
    }
    final result = BackupValidator.fromDocument(document);
    expect(result.firstTransactionDate, isNull);
    expect(result.lastTransactionDate, isNull);
  });
  test('row limits are checked before copying or validating rows', () {
    final document = backupDocument();
    document['data']['transactions'] = List<Object?>.filled(
      backupMaxRowsPerTable + 1,
      null,
    );
    document['counts']['transactions'] = backupMaxRowsPerTable + 1;
    expect(() => BackupValidator.fromDocument(document), invalid);
  });
  test('JSON escaping cannot bypass the encoded output size cap', () {
    final document = backupDocument();
    final template = Map<String, dynamic>.from(
      document['data']['transactions'][0] as Map<String, dynamic>,
    );
    document['data']['transactions'] = [
      for (var i = 0; i < 2500; i++)
        {
          ...template,
          'id': '12345678-1234-4234-8234-${i.toString().padLeft(12, '0')}',
          'note': '\u0001' * 2000,
        },
    ];
    document['counts']['transactions'] = 2500;
    final backup = BackupValidator.fromDocument(document);
    expect(backup.encode, invalid);
  });
  test(
    'strict JSON preflight rejects malformed, duplicate and deep content',
    () {
      final source = jsonEncode(backupDocument());
      for (final bad in [
        '',
        '{',
        '[]',
        source.replaceFirst('{', '{"format":"x",'),
        source.replaceFirst('{', r'{"\u0066ormat":"x",'),
        '${'[' * 17}0${']' * 17}',
        '{"a":"unterminated}',
        '{]',
      ]) {
        expect(
          () => BackupValidator.decode(bytes(bad)),
          invalid,
          reason: bad.length < 100 ? bad : 'duplicate',
        );
      }
      expect(() => BackupValidator.decode(Uint8List.fromList([0xff])), invalid);
      expect(
        () => BackupValidator.decode(Uint8List(backupMaxBytes + 1)),
        invalid,
      );
    },
  );
  test('native row validation rejects unknown columns and invalid flags', () {
    final backup = BackupValidator.fromDocument(backupDocument());
    final tables = {
      for (final table in backup.tables.entries)
        table.key: [
          for (final row in table.value) Map<String, Object?>.of(row),
        ],
    };
    tables['categories']!.first['is_archived'] = 2;
    expect(
      () => BackupValidator.fromDatabaseRows(
        tables: tables,
        appVersion: 'test',
        exportedAtUtc: DateTime.now(),
      ),
      invalid,
    );
    tables['categories']!.first['is_archived'] = 1;
    tables['categories']!.first['unknown'] = 'x';
    expect(
      () => BackupValidator.fromDatabaseRows(
        tables: tables,
        appVersion: 'test',
        exportedAtUtc: DateTime.now(),
      ),
      invalid,
    );
  });
  test('restore plan binds data and preserves protected MYR', () {
    final document = backupDocument();
    document['data']['categories'][0]['name'] =
        "Food'); DROP TABLE transactions; --";
    final plan = replacementStatements(
      BackupValidator.fromDocument(document),
    ).toList();
    expect(plan.take(4).map((s) => s.sql), [
      'DELETE FROM transactions',
      'DELETE FROM categories',
      "DELETE FROM currencies WHERE code <> 'MYR'",
      'DELETE FROM app_settings',
    ]);
    expect(plan[4].sql, contains('ON CONFLICT(code) DO UPDATE'));
    expect(
      plan.any(
        (s) =>
            s.sql.contains('REPLACE') ||
            s.sql.contains('DROP') ||
            s.sql.contains('PRAGMA'),
      ),
      isFalse,
    );
    expect(
      plan.any(
        (s) => s.arguments.contains(document['data']['categories'][0]['name']),
      ),
      isTrue,
    );
    expect(plan.any((s) => s.sql.contains("Food'")), isFalse);
  });
  test('stream reader bounds unknown and dishonest provider lengths', () async {
    expect(
      await readBackupStream(
        Stream.fromIterable([
          [1],
          [2, 3],
        ]),
      ),
      [1, 2, 3],
    );
    await expectLater(readBackupStream(const Stream.empty()), invalid);
    await expectLater(
      readBackupStream(Stream.value([1]), reportedLength: backupMaxBytes + 1),
      invalid,
    );
    var consumed = 0;
    Stream<List<int>> excessive() async* {
      consumed++;
      yield Uint8List(backupMaxBytes);
      consumed++;
      yield [1];
      consumed++;
      yield [2];
    }

    await expectLater(
      readBackupStream(excessive(), reportedLength: 1),
      invalid,
    );
    expect(consumed, 2);
  });
}
