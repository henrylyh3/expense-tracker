import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/dates/calendar_date.dart';
import '../../../core/models/ledger_types.dart';
import '../../../core/money/money.dart';
import '../domain/conversion_policy.dart';
import '../domain/ledger_transaction.dart';
import '../domain/transaction_input.dart';
import '../domain/transaction_filter.dart';
import 'history_predicate.dart';

class TransactionRepository {
  TransactionRepository(this._database);
  final AppDatabase _database;

  static const _projection = '''SELECT t.*, c.name AS category_name,
    c.icon_key AS category_icon_key, c.color_hex AS category_color_hex,
    c.is_archived AS category_archived, u.decimal_places,
    u.is_active AS currency_active
    FROM transactions t JOIN categories c ON c.id = t.category_id
    JOIN currencies u ON u.code = t.currency_code''';

  /// Returns one look-ahead row for the History screen's Load more action.
  Stream<List<LedgerTransaction>> watchHistory({
    int limit = 100,
    String? tripId,
    TransactionFilter filter = const TransactionFilter.empty(),
  }) {
    if (limit < 1) {
      throw const LedgerException('History limit must be positive.');
    }
    final fetchLimit = Money.checkedMinorUnits(BigInt.from(limit) + BigInt.one);
    final predicate = buildHistoryPredicate(filter, tripId: tripId);
    return _database
        .customSelect(
          '$_projection${predicate.sql} ORDER BY t.transaction_date DESC, t.created_at_utc DESC, t.id DESC LIMIT ?',
          variables: [
            for (final argument in predicate.arguments)
              Variable<String>(argument),
            Variable<int>(fetchLimit),
          ],
          readsFrom: {
            _database.transactions,
            _database.categories,
            _database.currencies,
          },
        )
        .watch()
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<LedgerTransaction?> watchById(String id, {String? tripId}) => _database
      .customSelect(
        '$_projection WHERE t.id = ?${tripId == null ? '' : ' AND t.trip_id = ?'}',
        variables: [
          Variable<String>(id),
          if (tripId != null) Variable<String>(tripId),
        ],
        readsFrom: {
          _database.transactions,
          _database.categories,
          _database.currencies,
        },
      )
      .watchSingleOrNull()
      .map((row) => row == null ? null : _fromRow(row));

  Future<LedgerTransaction> getById(String id) async {
    final row = await _database
        .customSelect(
          '$_projection WHERE t.id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw const LedgerException('This transaction no longer exists.');
    }
    return _fromRow(row);
  }

  Future<String> save(
    TransactionInput input, {
    String? id,
    int? expectedUpdatedAtUtc,
  }) => _database.writeTransaction(() async {
    final previous = id == null ? null : await getById(id);
    if (previous != null) _checkRevision(previous, expectedUpdatedAtUtc);
    final category = await _database
        .customSelect(
          'SELECT type, is_archived FROM categories WHERE id = ?',
          variables: [Variable<String>(input.categoryId)],
        )
        .getSingleOrNull();
    if (category == null || category.read<String>('type') != input.type.name) {
      throw const LedgerException(
        'Choose a category matching the transaction type.',
      );
    }
    if (category.read<int>('is_archived') != 0 &&
        previous?.categoryId != input.categoryId) {
      throw const LedgerException(
        'Archived categories cannot be selected for new transactions.',
      );
    }
    final trip = await _database
        .customSelect(
          id == null
              ? """SELECT COALESCE((SELECT value FROM app_settings WHERE key = 'active_trip'), 'personal') AS trip_id"""
              : 'SELECT trip_id FROM transactions WHERE id = ?',
          variables: [if (id != null) Variable.withString(id)],
        )
        .getSingle();
    final tripId = trip.read<String>('trip_id');
    final currency = await _database
        .customSelect(
          '''SELECT c.decimal_places, COALESCE(n.rate_to_myr, r.rate_to_myr, c.rate_to_myr) AS rate_to_myr, c.is_active
          FROM currencies c LEFT JOIN trip_rates r ON r.currency_code = c.code AND r.trip_id = ?
          LEFT JOIN currency_rates n ON n.id = r.rate_id
          WHERE c.code = ?''',
          variables: [
            Variable.withString(tripId),
            Variable<String>(input.currencyCode),
          ],
        )
        .getSingleOrNull();
    if (currency == null) {
      throw const LedgerException('Choose a configured currency.');
    }
    if (currency.read<int>('is_active') == 0 &&
        previous?.conversion.original.currencyCode != input.currencyCode) {
      throw const LedgerException(
        'Archived currencies cannot be selected for new transactions.',
      );
    }
    final original = Money.parsePositive(
      input.amountText,
      currencyCode: input.currencyCode,
      decimalPlaces: currency.read<int>('decimal_places'),
    );
    final conversion = resolveConversion(
      original: original,
      defaultRate: currency.read<String>('rate_to_myr'),
      previous: previous?.conversion,
      rateOverride: input.rateOverride,
      currencyChangeConfirmed: input.currencyChangeConfirmed,
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (previous == null) {
      final newId = const Uuid().v4();
      await _database.customInsert(
        '''INSERT INTO transactions (id, category_id, type, amount_minor, currency_code,
          exchange_rate_snapshot, amount_myr_minor, transaction_date, note, created_at_utc, updated_at_utc, trip_id)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        variables: [
          Variable<String>(newId),
          Variable<String>(input.categoryId),
          Variable<String>(input.type.name),
          Variable<int>(conversion.original.minorUnits),
          Variable<String>(conversion.original.currencyCode),
          Variable<String>(conversion.exchangeRate),
          Variable<int>(conversion.myr.minorUnits),
          Variable<String>(input.date.toString()),
          Variable<String>(input.note),
          Variable<int>(now),
          Variable<int>(now),
          Variable.withString(tripId),
        ],
        updates: {_database.transactions},
      );
      return newId;
    }
    // The timestamp doubles as an optimistic revision and must increase even
    // for two saves in one millisecond or when the device clock moves backwards.
    final updatedAt = now > previous.updatedAtUtc
        ? now
        : Money.checkedMinorUnits(
            BigInt.from(previous.updatedAtUtc) + BigInt.one,
          );
    await _database.customUpdate(
      '''UPDATE transactions SET category_id = ?, type = ?, amount_minor = ?, currency_code = ?,
         exchange_rate_snapshot = ?, amount_myr_minor = ?, transaction_date = ?, note = ?, updated_at_utc = ?
         WHERE id = ?''',
      variables: [
        Variable<String>(input.categoryId),
        Variable<String>(input.type.name),
        Variable<int>(conversion.original.minorUnits),
        Variable<String>(conversion.original.currencyCode),
        Variable<String>(conversion.exchangeRate),
        Variable<int>(conversion.myr.minorUnits),
        Variable<String>(input.date.toString()),
        Variable<String>(input.note),
        Variable<int>(updatedAt),
        Variable<String>(previous.id),
      ],
      updates: {_database.transactions},
      updateKind: UpdateKind.update,
    );
    return previous.id;
  });

  Future<void> delete(String id, {required int expectedUpdatedAtUtc}) =>
      _database.writeTransaction(() async {
        final previous = await getById(id);
        _checkRevision(previous, expectedUpdatedAtUtc);
        await _database.customUpdate(
          'DELETE FROM transactions WHERE id = ?',
          variables: [Variable<String>(id)],
          updates: {_database.transactions},
          updateKind: UpdateKind.delete,
        );
      });

  static void _checkRevision(LedgerTransaction previous, int? expected) {
    if (expected == null || expected != previous.updatedAtUtc) {
      throw const LedgerException(
        'This transaction changed. Reload it before saving or deleting.',
      );
    }
  }

  static LedgerTransaction _fromRow(QueryRow row) => LedgerTransaction(
    id: row.read<String>('id'),
    categoryId: row.read<String>('category_id'),
    categoryName: row.read<String>('category_name'),
    categoryIconKey: row.read<String>('category_icon_key'),
    categoryColorHex: row.read<String>('category_color_hex'),
    categoryArchived: row.read<int>('category_archived') != 0,
    currencyActive: row.read<int>('currency_active') != 0,
    type: TransactionType.values.byName(row.read<String>('type')),
    conversion: ConversionSnapshot(
      original: Money.fromMinor(
        minorUnits: row.read<int>('amount_minor'),
        currencyCode: row.read<String>('currency_code'),
        decimalPlaces: row.read<int>('decimal_places'),
      ),
      exchangeRate: row.read<String>('exchange_rate_snapshot'),
      myr: Money.fromMinor(
        minorUnits: row.read<int>('amount_myr_minor'),
        currencyCode: 'MYR',
        decimalPlaces: 2,
      ),
    ),
    date: CalendarDate.parse(row.read<String>('transaction_date')),
    note: row.readNullable<String>('note'),
    createdAtUtc: row.read<int>('created_at_utc'),
    updatedAtUtc: row.read<int>('updated_at_utc'),
  );
}
