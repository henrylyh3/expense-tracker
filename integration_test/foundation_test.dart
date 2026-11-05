import 'package:drift/drift.dart' show Variable;
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Run on a test installation. Does not delete or reset the database.
  testWidgets('native private storage persists across database reconnects', (
    tester,
  ) async {
    // A unique key avoids overwriting a setting left by any other test run.
    final key = 'integration_${const Uuid().v4()}';
    final first = AppDatabase();
    try {
      await first.initialize();
      await first.customStatement(
        'INSERT INTO app_settings (key, value) VALUES (?, ?)',
        [key, 'persisted'],
      );
    } finally {
      await first.close();
    }

    final database = AppDatabase();
    var opened = false;
    try {
      await database.initialize();
      opened = true;
      final row = await database
          .customSelect(
            'SELECT value FROM app_settings WHERE key = ?',
            variables: [Variable<String>(key)],
          )
          .getSingle();
      expect(row.read<String>('value'), 'persisted');
    } finally {
      try {
        if (opened) {
          await database.customStatement(
            'DELETE FROM app_settings WHERE key = ?',
            [key],
          );
        }
      } finally {
        await database.close();
      }
    }
  });
}
