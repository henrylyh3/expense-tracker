import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/ledger_types.dart';
import '../domain/ledger_category.dart';

class CategoryRepository {
  CategoryRepository(this._database);
  final AppDatabase _database;

  static const _projection = '''SELECT c.*,
    (SELECT count(*) FROM transactions t WHERE t.category_id = c.id) AS usage_count
    FROM categories c''';

  Stream<List<LedgerCategory>> watchAll() => _database
      .customSelect(
        '$_projection ORDER BY c.is_archived, c.type, c.sort_order, c.name, c.id',
        readsFrom: {_database.categories, _database.transactions},
      )
      .watch()
      .map((rows) => rows.map(_fromRow).toList(growable: false));

  Future<LedgerCategory> getById(String id) async {
    final row = await _database
        .customSelect(
          '$_projection WHERE c.id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw const LedgerException('This category no longer exists.');
    }
    return _fromRow(row);
  }

  Future<String> save(
    CategoryDraft draft, {
    String? id,
  }) => _database.writeTransaction(() async {
    final existing = id == null ? null : await getById(id);
    if (existing != null && existing.isUsed && existing.type != draft.type) {
      throw const LedgerException(
        'A category with transactions cannot change type.',
      );
    }
    final names = await _database
        .customSelect(
          'SELECT id, name FROM categories WHERE type = ?',
          variables: [Variable<String>(draft.type.name)],
        )
        .get();
    if (names.any(
      (row) =>
          row.read<String>('id') != id &&
          row.read<String>('name').toLowerCase() == draft.name.toLowerCase(),
    )) {
      throw const LedgerException(
        'A category with this name and type already exists, including archived categories.',
      );
    }
    if (existing == null) {
      final newId = const Uuid().v4();
      await _database.customInsert(
        '''INSERT INTO categories (id, name, type, icon_key, color_hex, sort_order, is_archived)
           VALUES (?, ?, ?, ?, ?, (SELECT COALESCE(MAX(sort_order), -1) + 1 FROM categories), 0)''',
        variables: [
          Variable<String>(newId),
          Variable<String>(draft.name),
          Variable<String>(draft.type.name),
          Variable<String>(draft.iconKey),
          Variable<String>(draft.colorHex),
        ],
        updates: {_database.categories},
      );
      return newId;
    }
    await _database.customUpdate(
      'UPDATE categories SET name = ?, type = ?, icon_key = ?, color_hex = ? WHERE id = ?',
      variables: [
        Variable<String>(draft.name),
        Variable<String>(draft.type.name),
        Variable<String>(draft.iconKey),
        Variable<String>(draft.colorHex),
        Variable<String>(existing.id),
      ],
      updates: {_database.categories},
      updateKind: UpdateKind.update,
    );
    return existing.id;
  });

  /// Reference checks and the resulting write share one transaction, so a
  /// caller's stale usage count can never cause historical data to be removed.
  Future<RemovalOutcome> remove(String id) =>
      _database.writeTransaction(() async {
        final category = await getById(id);
        if (category.isUsed) {
          await _setArchived(id, true);
          return RemovalOutcome.archived;
        }
        await _database.customUpdate(
          'DELETE FROM categories WHERE id = ?',
          variables: [Variable<String>(id)],
          updates: {_database.categories},
          updateKind: UpdateKind.delete,
        );
        return RemovalOutcome.deleted;
      });

  Future<void> restore(String id) => _database.writeTransaction(() async {
    await getById(id);
    await _setArchived(id, false);
  });

  Future<void> _setArchived(String id, bool archived) async {
    await _database.customUpdate(
      'UPDATE categories SET is_archived = ? WHERE id = ?',
      variables: [Variable<int>(archived ? 1 : 0), Variable<String>(id)],
      updates: {_database.categories},
      updateKind: UpdateKind.update,
    );
  }

  static LedgerCategory _fromRow(QueryRow row) => LedgerCategory(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    type: TransactionType.values.byName(row.read<String>('type')),
    iconKey: row.read<String>('icon_key'),
    colorHex: row.read<String>('color_hex'),
    sortOrder: row.read<int>('sort_order'),
    isArchived: row.read<int>('is_archived') != 0,
    usageCount: row.read<int>('usage_count'),
  );
}
