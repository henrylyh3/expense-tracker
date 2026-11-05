import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/ledger_types.dart';
import '../domain/configured_currency.dart';

class CurrencyRepository {
  CurrencyRepository(this._database);
  final AppDatabase _database;

  static const _projection = '''SELECT c.*,
    (SELECT count(*) FROM transactions t WHERE t.currency_code = c.code) AS usage_count
    FROM currencies c''';

  Stream<List<ConfiguredCurrency>> watchAll() => _database
      .customSelect(
        "$_projection ORDER BY (c.code = 'MYR') DESC, c.is_active DESC, c.code",
        readsFrom: {_database.currencies, _database.transactions},
      )
      .watch()
      .map((rows) => rows.map(_fromRow).toList(growable: false));

  Future<ConfiguredCurrency> getByCode(String code) async {
    final row = await _database
        .customSelect(
          '$_projection WHERE c.code = ?',
          variables: [Variable<String>(code)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw const LedgerException('This currency no longer exists.');
    }
    return _fromRow(row);
  }

  Future<void> save(
    CurrencyDraft draft, {
    String? originalCode,
  }) => _database.writeTransaction(() async {
    final existing = originalCode == null
        ? null
        : await getByCode(originalCode);
    if (existing != null) {
      if (existing.isBase && draft.code != 'MYR') {
        throw const LedgerException('MYR is the fixed base currency.');
      }
      if (existing.isUsed &&
          (existing.code != draft.code ||
              existing.decimalPlaces != draft.decimalPlaces)) {
        throw const LedgerException(
          'A used currency cannot change its code or decimal places.',
        );
      }
    }
    final duplicate = await _database
        .customSelect(
          'SELECT code FROM currencies WHERE code = ?',
          variables: [Variable<String>(draft.code)],
        )
        .getSingleOrNull();
    if (duplicate != null && existing?.code != draft.code) {
      throw const LedgerException(
        'This currency code already exists, possibly archived.',
      );
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (existing == null) {
      await _database.customInsert(
        '''INSERT INTO currencies
           (code, name, symbol, decimal_places, rate_to_myr, is_active, created_at_utc, updated_at_utc)
           VALUES (?, ?, ?, ?, ?, 1, ?, ?)''',
        variables: [
          Variable<String>(draft.code),
          Variable<String>(draft.name),
          Variable<String>(draft.symbol),
          Variable<int>(draft.decimalPlaces),
          Variable<String>(draft.rateToMyr),
          Variable<int>(now),
          Variable<int>(now),
        ],
        updates: {_database.currencies},
      );
    } else {
      // Never touch transactions: snapshots and stored MYR values are facts.
      // Preserve archive status and creation time even if the device clock moves back.
      await _database.customUpdate(
        '''UPDATE currencies SET code = ?, name = ?, symbol = ?, decimal_places = ?,
           rate_to_myr = ?, updated_at_utc = MAX(updated_at_utc, ?) WHERE code = ?''',
        variables: [
          Variable<String>(draft.code),
          Variable<String>(draft.name),
          Variable<String>(draft.symbol),
          Variable<int>(draft.decimalPlaces),
          Variable<String>(draft.rateToMyr),
          Variable<int>(now),
          Variable<String>(existing.code),
        ],
        updates: {_database.currencies},
        updateKind: UpdateKind.update,
      );
    }
  });

  Future<RemovalOutcome> remove(String code) =>
      _database.writeTransaction(() async {
        final currency = await getByCode(code);
        if (currency.isBase) {
          throw const LedgerException('MYR cannot be deleted or archived.');
        }
        if (currency.isUsed) {
          await _setActive(code, false);
          return RemovalOutcome.archived;
        }
        await _database.customUpdate(
          'DELETE FROM currencies WHERE code = ?',
          variables: [Variable<String>(code)],
          updates: {_database.currencies},
          updateKind: UpdateKind.delete,
        );
        return RemovalOutcome.deleted;
      });

  Future<void> restore(String code) => _database.writeTransaction(() async {
    await getByCode(code);
    await _setActive(code, true);
  });

  Future<void> _setActive(String code, bool active) async {
    await _database.customUpdate(
      'UPDATE currencies SET is_active = ?, updated_at_utc = MAX(updated_at_utc, ?) WHERE code = ?',
      variables: [
        Variable<int>(active ? 1 : 0),
        Variable<int>(DateTime.now().toUtc().millisecondsSinceEpoch),
        Variable<String>(code),
      ],
      updates: {_database.currencies},
      updateKind: UpdateKind.update,
    );
  }

  static ConfiguredCurrency _fromRow(QueryRow row) => ConfiguredCurrency(
    code: row.read<String>('code'),
    name: row.read<String>('name'),
    symbol: row.read<String>('symbol'),
    decimalPlaces: row.read<int>('decimal_places'),
    rateToMyr: row.read<String>('rate_to_myr'),
    isActive: row.read<int>('is_active') != 0,
    usageCount: row.read<int>('usage_count'),
  );
}
