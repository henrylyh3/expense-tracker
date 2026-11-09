import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/ledger_types.dart';
import '../domain/configured_currency.dart';

class CurrencyRepository {
  CurrencyRepository(this._database);
  final AppDatabase _database;

  static const _projection = '''SELECT c.*, NULL AS record_id,
    (SELECT count(*) FROM transactions t WHERE t.currency_code = c.code) +
    (SELECT count(*) FROM currency_rates r WHERE r.currency_code = c.code) AS usage_count
    FROM currencies c
    UNION ALL SELECT c.code, r.name, c.symbol, c.decimal_places, r.rate_to_myr,
      r.is_active, c.created_at_utc, c.updated_at_utc, r.id AS record_id,
      (SELECT count(*) FROM trip_rates t WHERE t.rate_id = r.id) +
      (SELECT count(*) FROM transactions t WHERE t.currency_code = c.code) AS usage_count
    FROM currency_rates r JOIN currencies c ON c.code = r.currency_code''';

  Stream<List<ConfiguredCurrency>> watchAll() => _database
      .customSelect(
        "SELECT * FROM ($_projection) ORDER BY code, name COLLATE NOCASE, record_id",
        readsFrom: {
          _database.currencies,
          _database.transactions,
          _database.currencyRates,
          _database.tripRates,
        },
      )
      .watch()
      .map((rows) => rows.map(_fromRow).toList(growable: false));

  Future<ConfiguredCurrency> getByCode(String code) async {
    final row = await _database
        .customSelect(
          'SELECT * FROM ($_projection) WHERE COALESCE(record_id, code) = ?',
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
    if (existing == null ||
        CurrencyDraft.nameKey(existing.name) !=
            CurrencyDraft.nameKey(draft.name)) {
      final names = await _database
          .customSelect(
            'SELECT code AS record_key, name FROM currencies UNION ALL SELECT id AS record_key, name FROM currency_rates',
          )
          .get();
      if (names.any(
        (row) =>
            row.read<String>('record_key') != existing?.key &&
            CurrencyDraft.nameKey(row.read<String>('name')) ==
                CurrencyDraft.nameKey(draft.name),
      )) {
        throw const LedgerException(
          'This currency name is already used. Choose another name.',
        );
      }
    }
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
    if (existing?.recordId != null) {
      if (draft.code != existing!.code ||
          draft.decimalPlaces != existing.decimalPlaces) {
        throw const LedgerException(
          'A named currency record keeps its currency code and precision.',
        );
      }
      await _database.customUpdate(
        'UPDATE currency_rates SET name = ?, rate_to_myr = ? WHERE id = ?',
        variables: [
          Variable.withString(draft.name),
          Variable.withString(draft.rateToMyr),
          Variable.withString(existing.key),
        ],
        updates: {_database.currencyRates},
      );
      await _database.customUpdate(
        'UPDATE trip_rates SET name = ?, rate_to_myr = ? WHERE rate_id = ?',
        variables: [
          Variable.withString(draft.name),
          Variable.withString(draft.rateToMyr),
          Variable.withString(existing.key),
        ],
        updates: {_database.tripRates},
      );
      return;
    }
    final duplicate = await _database
        .customSelect(
          'SELECT code FROM currencies WHERE code = ?',
          variables: [Variable<String>(draft.code)],
        )
        .getSingleOrNull();
    if (duplicate != null && existing?.code != draft.code) {
      if (draft.code == 'MYR') {
        throw const LedgerException('MYR is the fixed base currency.');
      }
      final base = await getByCode(draft.code);
      if (base.decimalPlaces != draft.decimalPlaces) {
        throw const LedgerException(
          'Use the configured decimal precision for this currency.',
        );
      }
      await _database.customInsert(
        'INSERT INTO currency_rates (id, currency_code, name, rate_to_myr) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString(const Uuid().v4()),
          Variable.withString(draft.code),
          Variable.withString(draft.name),
          Variable.withString(draft.rateToMyr),
        ],
        updates: {_database.currencyRates},
      );
      return;
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

  Future<RemovalOutcome> remove(String code) => _database.writeTransaction(
    () async {
      final currency = await getByCode(code);
      if (currency.recordId != null) {
        if (!currency.isUsed) {
          await _database.customUpdate(
            'DELETE FROM currency_rates WHERE id = ?',
            variables: [Variable.withString(currency.key)],
            updates: {_database.currencyRates},
          );
          await _database.customUpdate(
            "DELETE FROM app_settings WHERE key = 'default_rate' AND value = ?",
            variables: [Variable.withString(currency.key)],
            updates: {_database.appSettings},
          );
          return RemovalOutcome.deleted;
        }
        await _database.customUpdate(
          'UPDATE currency_rates SET is_active = 0 WHERE id = ?',
          variables: [Variable.withString(currency.key)],
          updates: {_database.currencyRates},
        );
        return RemovalOutcome.archived;
      }
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
    },
  );

  Future<void> restore(String code) => _database.writeTransaction(() async {
    await getByCode(code);
    await _setActive(code, true);
  });

  Future<void> _setActive(String code, bool active) async {
    final record = await getByCode(code);
    if (record.recordId != null) {
      await _database.customUpdate(
        'UPDATE currency_rates SET is_active = ? WHERE id = ?',
        variables: [
          Variable.withInt(active ? 1 : 0),
          Variable.withString(code),
        ],
        updates: {_database.currencyRates},
      );
      return;
    }
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
    recordId: row.readNullable<String>('record_id'),
    code: row.read<String>('code'),
    name: row.read<String>('name'),
    symbol: row.read<String>('symbol'),
    decimalPlaces: row.read<int>('decimal_places'),
    rateToMyr: row.read<String>('rate_to_myr'),
    isActive: row.read<int>('is_active') != 0,
    usageCount: row.read<int>('usage_count'),
  );
}
