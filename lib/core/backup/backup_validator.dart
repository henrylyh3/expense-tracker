import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import '../dates/calendar_date.dart';
import '../models/ledger_types.dart';
import '../money/currency_converter.dart';
import '../money/exchange_rate.dart';
import '../money/money.dart';

const backupMaxBytes = 25 * 1024 * 1024;
const backupMaxRowsPerTable = 100000;
const backupColumns = <String, List<String>>{
  'categories': [
    'id',
    'name',
    'type',
    'icon_key',
    'color_hex',
    'sort_order',
    'is_archived',
  ],
  'currencies': [
    'code',
    'name',
    'symbol',
    'decimal_places',
    'rate_to_myr',
    'is_active',
    'created_at_utc',
    'updated_at_utc',
  ],
  'transactions': [
    'id',
    'category_id',
    'type',
    'amount_minor',
    'currency_code',
    'exchange_rate_snapshot',
    'amount_myr_minor',
    'transaction_date',
    'note',
    'created_at_utc',
    'updated_at_utc',
    'trip_id',
  ],
  'trips': ['id', 'name'],
  'trip_rates': ['trip_id', 'currency_code', 'rate_to_myr', 'name', 'rate_id'],
  'currency_rates': ['id', 'currency_code', 'name', 'rate_to_myr', 'is_active'],
  'settings': ['key', 'value'],
};
const _stringIntegers = <String, Set<String>>{
  'categories': {'sort_order'},
  'currencies': {'created_at_utc', 'updated_at_utc'},
  'transactions': {
    'amount_minor',
    'amount_myr_minor',
    'created_at_utc',
    'updated_at_utc',
  },
};

/// Only the validator can construct this deeply immutable, database-ready value.
final class ValidatedBackup {
  ValidatedBackup._(
    this.appVersion,
    this.exportedAtUtc,
    Map<String, List<Map<String, Object?>>> tables,
  ) : tables = Map.unmodifiable({
        for (final table in tables.entries)
          table.key: List<Map<String, Object?>>.unmodifiable(
            table.value.map((row) => Map<String, Object?>.unmodifiable(row)),
          ),
      });

  final String appVersion;
  final DateTime exportedAtUtc;
  final Map<String, List<Map<String, Object?>>> tables;
  int count(String table) => tables[table]!.length;
  String? get firstTransactionDate => _edgeDate(false);
  String? get lastTransactionDate => _edgeDate(true);
  String? _edgeDate(bool last) {
    String? result;
    for (final row in tables['transactions']!) {
      final date = row['transaction_date']! as String;
      if (result == null ||
          (last ? date.compareTo(result) > 0 : date.compareTo(result) < 0)) {
        result = date;
      }
    }
    return result;
  }

  Map<String, Object?> toDocument() => {
    'format': 'expense-tracker',
    'format_version': 1,
    'schema_version': 4,
    'app_version': appVersion,
    'exported_at_utc': exportedAtUtc.toIso8601String(),
    'base_currency': 'MYR',
    'counts': {for (final name in backupColumns.keys) name: count(name)},
    'data': {
      for (final table in tables.entries)
        table.key: table.value.map((row) => _jsonRow(table.key, row)).toList(),
    },
  };

  Uint8List encode() {
    final output = _LimitedBytes();
    final encoder = JsonUtf8Encoder().startChunkedConversion(output);
    encoder.add(toDocument());
    encoder.close();
    return output.bytes.takeBytes();
  }
}

Map<String, Object?> _jsonRow(String table, Map<String, Object?> row) => {
  for (final column in backupColumns[table]!)
    column:
        (_stringIntegers[table]?.contains(column) ?? false) &&
            row[column] is int
        ? row[column].toString()
        : (column == 'is_archived' || column == 'is_active') &&
              (row[column] == 0 || row[column] == 1)
        ? row[column] == 1
        : row[column],
};

class _LimitedBytes implements Sink<List<int>> {
  final bytes = BytesBuilder(copy: false);
  int length = 0;
  @override
  void add(List<int> chunk) {
    length += chunk.length;
    if (length > backupMaxBytes) {
      throw const LedgerException('The backup exceeds the 25 MiB limit.');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}

abstract final class BackupValidator {
  static Future<ValidatedBackup> decodeInBackground(Uint8List bytes) =>
      Isolate.run(() => decode(bytes));

  static Future<ValidatedBackup> snapshotInBackground({
    required Map<String, List<Map<String, Object?>>> tables,
    required DateTime exportedAtUtc,
    required String appVersion,
  }) => Isolate.run(
    () => fromDatabaseRows(
      tables: tables,
      appVersion: appVersion,
      exportedAtUtc: exportedAtUtc,
    ),
  );

  static ValidatedBackup decode(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > backupMaxBytes) {
      throw const LedgerException(
        'Choose a non-empty JSON backup no larger than 25 MiB.',
      );
    }
    try {
      final source = utf8.decode(bytes, allowMalformed: false);
      _checkJsonStructure(source);
      return fromDocument(jsonDecode(source));
    } on FormatException {
      throw const LedgerException('This is not a valid UTF-8 JSON backup.');
    }
  }

  static ValidatedBackup fromDatabaseRows({
    required Map<String, List<Map<String, Object?>>> tables,
    required String appVersion,
    required DateTime exportedAtUtc,
  }) {
    _object(tables, backupColumns.keys.toSet());
    for (final table in tables.entries) {
      for (final row in table.value) {
        _object(row, backupColumns[table.key]!.toSet());
      }
    }
    return fromDocument({
      'format': 'expense-tracker',
      'format_version': 1,
      'schema_version': 4,
      'app_version': appVersion,
      'exported_at_utc': exportedAtUtc.toUtc().toIso8601String(),
      'base_currency': 'MYR',
      'counts': {
        for (final name in backupColumns.keys) name: tables[name]?.length ?? -1,
      },
      'data': {
        for (final table in tables.entries)
          table.key: table.value
              .map((row) => _jsonRow(table.key, row))
              .toList(),
      },
    });
  }

  static ValidatedBackup fromDocument(Object? document) {
    final root = _object(document, {
      'format',
      'format_version',
      'schema_version',
      'app_version',
      'exported_at_utc',
      'base_currency',
      'counts',
      'data',
    });
    if (root['format'] != 'expense-tracker' ||
        root['format_version'] is! int ||
        root['format_version'] != 1 ||
        root['schema_version'] is! int ||
        !{1, 2, 3, 4}.contains(root['schema_version'])) {
      throw const LedgerException(
        'This backup format or schema version is not supported.',
      );
    }
    if (root['base_currency'] != 'MYR') {
      _invalid('The base currency must be MYR.');
    }
    final version = _text(root, 'app_version', 80);
    final exportedText = _text(root, 'exported_at_utc', 32);
    final exported = DateTime.tryParse(exportedText);
    if (exported == null ||
        !exported.isUtc ||
        exported.year < 1 ||
        exported.year > 9999 ||
        exported.toIso8601String() != exportedText) {
      _invalid('The export timestamp must be a canonical UTC ISO-8601 string.');
    }
    final schema = root['schema_version'];
    final legacy = schema == 1;
    final names = backupColumns.keys.toSet();
    if (legacy) names.removeAll({'trips', 'trip_rates'});
    if (schema != 4) names.remove('currency_rates');
    final data = _object(root['data'], names);
    final counts = _object(root['counts'], names);
    final tables = <String, List<Map<String, Object?>>>{};
    for (final name in names) {
      final rows = data[name];
      if (rows is! List<Object?> ||
          rows.length > backupMaxRowsPerTable ||
          counts[name] is! int ||
          counts[name] != rows.length) {
        _invalid('Table counts or row limits are invalid.');
      }
      tables[name] = [
        for (final value in rows)
          Map<String, Object?>.from(
            _object(
              value,
              backupColumns[name]!
                  .where(
                    (column) =>
                        (!legacy || column != 'trip_id') &&
                        (schema == 4 || column != 'rate_id') &&
                        (schema != 2 ||
                            name != 'trip_rates' ||
                            column != 'name'),
                  )
                  .toSet(),
            ),
          ),
      ];
    }

    if (legacy) {
      tables['trips'] = [
        {'id': 'personal', 'name': 'Personal'},
      ];
      tables['trip_rates'] = [];
      for (final row in tables['transactions']!) {
        row['trip_id'] = 'personal';
      }
    }
    final trips = <String>{};
    for (final row in tables['trips']!) {
      if (!trips.add(_text(row, 'id', 64))) _invalid('Duplicate trip ID.');
      _text(row, 'name', 80);
    }
    if (!trips.contains('personal')) _invalid('The Personal trip is missing.');

    final categories = <String, Map<String, Object?>>{};
    final categoryNames = <(String, String)>{};
    for (final row in tables['categories']!) {
      final id = _text(row, 'id', 64);
      final name = _text(row, 'name', 80);
      final type = _type(row);
      if (categories.containsKey(id) ||
          !categoryNames.add((type, name.toLowerCase()))) {
        _invalid('Category IDs or names are duplicated.');
      }
      if (!RegExp(
            r'^[a-z][a-z0-9_]{0,63}$',
          ).hasMatch(_text(row, 'icon_key', 64)) ||
          !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(_text(row, 'color_hex', 7))) {
        _invalid('Category icons or colors are invalid.');
      }
      row['sort_order'] = _integerString(row, 'sort_order');
      row['is_archived'] = _flag(row, 'is_archived');
      categories[id] = row;
    }

    final currencies = <String, Map<String, Object?>>{};
    for (final row in tables['currencies']!) {
      final code = _text(row, 'code', 3);
      if (!RegExp(r'^[A-Z]{3}$').hasMatch(code) ||
          currencies.containsKey(code)) {
        _invalid('Currency codes are invalid or duplicated.');
      }
      _text(row, 'name', 80);
      _text(row, 'symbol', 12);
      final precision = row['decimal_places'];
      if (precision is! int || precision < 0 || precision > 6) {
        _invalid('Currency precision is invalid.');
      }
      _rate(row, 'rate_to_myr');
      row['is_active'] = _flag(row, 'is_active');
      _timestamps(row);
      if (code == 'MYR' &&
          (precision != 2 ||
              row['rate_to_myr'] != '1' ||
              row['is_active'] != 1)) {
        _invalid('MYR must be active with precision 2 and rate 1.');
      }
      currencies[code] = row;
    }
    if (!currencies.containsKey('MYR')) {
      _invalid('The MYR currency is missing.');
    }

    if (schema != 4) {
      tables['currency_rates'] = [];
      for (final row in tables['trip_rates']!) {
        final id = 'trip:${row['trip_id']}:${row['currency_code']}';
        row['rate_id'] = id;
        tables['currency_rates']!.add({
          'id': id,
          'currency_code': row['currency_code'],
          'name': row['name'] ?? currencies[row['currency_code']]?['name'],
          'rate_to_myr': row['rate_to_myr'],
          'is_active': true,
        });
      }
    }
    final records = <String, Map<String, Object?>>{};
    for (final row in tables['currency_rates']!) {
      final id = _text(row, 'id', 80);
      final code = _text(row, 'currency_code', 3);
      if (records.containsKey(id) ||
          !currencies.containsKey(code) ||
          code == 'MYR') {
        _invalid('Currency records are duplicated or invalid.');
      }
      _text(row, 'name', 80);
      _rate(row, 'rate_to_myr');
      row['is_active'] = _flag(row, 'is_active');
      records[id] = row;
    }

    final rateKeys = <(String, String)>{};
    for (final row in tables['trip_rates']!) {
      if (schema == 2) row['name'] = null;
      if (row['name'] != null) _text(row, 'name', 80);
      final trip = _text(row, 'trip_id', 64);
      final code = _text(row, 'currency_code', 3);
      if (!trips.contains(trip) ||
          !currencies.containsKey(code) ||
          code == 'MYR' ||
          !rateKeys.add((trip, code))) {
        _invalid(
          'A trip rate is duplicated or references an invalid trip or currency.',
        );
      }
      _rate(row, 'rate_to_myr');
      final rateId = row['rate_id'];
      if (rateId != null &&
          (rateId is! String || records[rateId]?['currency_code'] != code)) {
        _invalid('A trip references an invalid currency record.');
      }
    }

    final transactionIds = <String>{};
    for (final row in tables['transactions']!) {
      final id = _text(row, 'id', 36);
      if (!RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(id) ||
          !transactionIds.add(id.toLowerCase())) {
        _invalid('Transaction UUIDs are invalid or duplicated.');
      }
      if (!trips.contains(_text(row, 'trip_id', 64))) {
        _invalid('A transaction references a missing trip.');
      }
      final category = categories[_text(row, 'category_id', 64)];
      final currency = currencies[_text(row, 'currency_code', 3)];
      if (category == null || currency == null) {
        _invalid('A transaction references a missing category or currency.');
      }
      if (_type(row) != category['type']) {
        _invalid('A transaction type does not match its category.');
      }
      final amount = _integerString(row, 'amount_minor', minimum: 1);
      final myr = _integerString(row, 'amount_myr_minor');
      final rate = _rate(row, 'exchange_rate_snapshot');
      final original = Money.fromMinor(
        minorUnits: amount,
        currencyCode: currency['code']! as String,
        decimalPlaces: currency['decimal_places']! as int,
      );
      if (CurrencyConverter.toMyr(original, rate).minorUnits != myr ||
          (currency['code'] == 'MYR' && rate != '1')) {
        _invalid('A saved MYR equivalent does not match its amount and rate.');
      }
      row['amount_minor'] = amount;
      row['amount_myr_minor'] = myr;
      CalendarDate.parse(_text(row, 'transaction_date', 10));
      final note = row['note'];
      if (note != null) {
        if (note is! String ||
            !_validUnicode(note) ||
            note.contains('\u0000') ||
            note.runes.length > 2000) {
          _invalid('Transaction notes are invalid.');
        }
      }
      _timestamps(row);
    }

    final settingKeys = <String>{};
    for (final row in tables['settings']!) {
      final key = _text(row, 'key', 80);
      final value = row['value'];
      final valid = switch (key) {
        'default_rate' => records.containsKey(value),
        'active_trip' => trips.contains(value),
        'theme_mode' => {'system', 'light', 'dark'}.contains(value),
        'default_currency' =>
          value is String && RegExp(r'^[A-Z]{3}$').hasMatch(value),
        _ =>
          key.startsWith('trip_currency:') &&
              trips.contains(key.substring('trip_currency:'.length)) &&
              value is String &&
              RegExp(r'^[A-Z]{3}$').hasMatch(value),
      };
      if (!settingKeys.add(key) || !valid) {
        _invalid('Settings are unsupported, duplicated or invalid.');
      }
    }
    if (!settingKeys.contains('theme_mode')) {
      _invalid('The appearance setting is missing.');
    }
    return ValidatedBackup._(version, exported, tables);
  }
}

Never _invalid(String message) =>
    throw LedgerException('Invalid backup: $message');
Map<String, Object?> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, Object?> ||
      value.length != keys.length ||
      !keys.every(value.containsKey)) {
    _invalid('An object has missing, unknown or invalid fields.');
  }
  return value;
}

bool _validUnicode(String value) => utf8.decode(utf8.encode(value)) == value;
String _text(Map<String, Object?> row, String key, int limit) {
  final value = row[key];
  if (value is! String ||
      value.isEmpty ||
      value != value.trim() ||
      value.runes.length > limit ||
      value.runes.any((rune) => rune < 32 || rune == 127) ||
      !_validUnicode(value)) {
    _invalid('A text field is invalid.');
  }
  return value;
}

String _type(Map<String, Object?> row) {
  final value = row['type'];
  if (value != 'income' && value != 'expense') {
    _invalid('A transaction/category type is invalid.');
  }
  return value! as String;
}

int _flag(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is! bool) {
    _invalid('Archive and active flags must be JSON booleans.');
  }
  return value ? 1 : 0;
}

int _integerString(
  Map<String, Object?> row,
  String key, {
  int minimum = 0,
  BigInt? maximum,
}) {
  final value = row[key];
  if (value is! String ||
      value.length > 19 ||
      !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(value)) {
    _invalid('Integer fields must be canonical decimal strings.');
  }
  final number = BigInt.parse(value);
  if (number < BigInt.from(minimum) ||
      number > (maximum ?? Money.maxMinorUnits)) {
    _invalid('An integer is outside its supported range.');
  }
  return number.toInt();
}

void _timestamps(Map<String, Object?> row) {
  final maximum = BigInt.from(
    DateTime.utc(9999, 12, 31, 23, 59, 59, 999).millisecondsSinceEpoch,
  );
  final created = _integerString(row, 'created_at_utc', maximum: maximum);
  final updated = _integerString(row, 'updated_at_utc', maximum: maximum);
  if (updated < created) _invalid('An update timestamp precedes creation.');
  row['created_at_utc'] = created;
  row['updated_at_utc'] = updated;
}

String _rate(Map<String, Object?> row, String key) {
  final rate = _text(row, key, 25);
  normalizeExchangeRate(rate); // Validate without rewriting historical strings.
  return rate;
}

/// Bound nesting before decoding, and reject duplicate keys including escaped
/// equivalents. jsonDecode remains responsible for full JSON grammar validation.
void _checkJsonStructure(String source) {
  final stack = <({int opener, Set<String>? keys})>[];
  for (var i = 0; i < source.length; i++) {
    final character = source.codeUnitAt(i);
    if (character == 34) {
      final start = i;
      var closed = false;
      for (i++; i < source.length; i++) {
        if (source.codeUnitAt(i) == 92) {
          i++;
          continue;
        }
        if (source.codeUnitAt(i) == 34) {
          closed = true;
          break;
        }
      }
      if (!closed) _invalid('JSON strings are incomplete.');
      var next = i + 1;
      while (next < source.length &&
          {9, 10, 13, 32}.contains(source.codeUnitAt(next))) {
        next++;
      }
      if (next < source.length &&
          source.codeUnitAt(next) == 58 &&
          stack.isNotEmpty &&
          stack.last.keys != null) {
        final key = jsonDecode(source.substring(start, i + 1)) as String;
        if (!stack.last.keys!.add(key)) {
          _invalid('JSON object keys are duplicated.');
        }
      }
    } else if (character == 123 || character == 91) {
      stack.add((
        opener: character,
        keys: character == 123 ? <String>{} : null,
      ));
      if (stack.length > 16) _invalid('JSON nesting is too deep.');
    } else if (character == 125 || character == 93) {
      if (stack.isEmpty || stack.last.opener != (character == 125 ? 123 : 91)) {
        _invalid('JSON containers are malformed.');
      }
      stack.removeLast();
    }
  }
  if (stack.isNotEmpty) _invalid('JSON containers are incomplete.');
}
