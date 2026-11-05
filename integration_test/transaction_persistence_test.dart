import 'package:drift/drift.dart' show UpdateKind, Variable;
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/dates/calendar_date.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/ledger_category.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/transaction_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Run on a test installation. Only this test's uniquely identified rows are removed.
  testWidgets(
    'native database reopen retains original money and conversion facts',
    (tester) async {
      String? categoryId;
      String? transactionId;
      final date = CalendarDate.today();
      try {
        await _withDatabase((database) async {
          categoryId = await CategoryRepository(database).save(
            CategoryDraft(
              name: 'Persistence ${const Uuid().v4()}',
              type: TransactionType.expense,
              iconKey: 'more_horiz',
              colorHex: '#123456',
            ),
          );
          transactionId = await TransactionRepository(database).save(
            TransactionInput(
              type: TransactionType.expense,
              categoryId: categoryId!,
              currencyCode: 'MYR',
              amountText: '12.50',
              date: date,
              note: 'Integration persistence probe',
            ),
          );
        });
        await _withDatabase((database) async {
          final item = await TransactionRepository(
            database,
          ).getById(transactionId!);
          expect(item.conversion.original.currencyCode, 'MYR');
          expect(item.conversion.original.minorUnits, 1250);
          expect(item.conversion.exchangeRate, '1');
          expect(item.conversion.myr.minorUnits, 1250);
          expect(item.categoryId, categoryId);
          expect(item.date.toString(), date.toString());
          expect(item.note, 'Integration persistence probe');
        });
      } finally {
        if (categoryId != null) {
          await _withDatabase(
            (database) => database.transaction(() async {
              if (transactionId != null) {
                await database.customUpdate(
                  'DELETE FROM transactions WHERE id = ?',
                  variables: [Variable<String>(transactionId)],
                  updates: {database.transactions},
                  updateKind: UpdateKind.delete,
                );
              }
              await database.customUpdate(
                'DELETE FROM categories WHERE id = ?',
                variables: [Variable<String>(categoryId)],
                updates: {database.categories},
                updateKind: UpdateKind.delete,
              );
            }),
          );
        }
      }
    },
  );
}

Future<void> _withDatabase(Future<void> Function(AppDatabase) action) async {
  final database = AppDatabase();
  try {
    await database.initialize();
    await action(database);
  } finally {
    await database.close();
  }
}
