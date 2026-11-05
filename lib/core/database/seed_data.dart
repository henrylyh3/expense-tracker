import 'package:drift/drift.dart';

/// Called only during first creation, never on a normal reopen.
Future<void> seedDatabase(GeneratedDatabase database) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await database.customStatement(
    '''INSERT INTO currencies
       (code, name, symbol, decimal_places, rate_to_myr, is_active,
        created_at_utc, updated_at_utc)
       VALUES ('MYR', 'Malaysian Ringgit', 'RM', 2, '1', 1, ?, ?)''',
    [now, now],
  );
  const categories = [
    ('food', 'Food', 'expense', 'restaurant', '#EF6C00'),
    ('shopping', 'Shopping', 'expense', 'shopping_bag', '#8E24AA'),
    ('transport', 'Transport', 'expense', 'directions_bus', '#1565C0'),
    ('bills', 'Bills', 'expense', 'receipt_long', '#546E7A'),
    ('health', 'Health', 'expense', 'medical_services', '#C62828'),
    ('entertainment', 'Entertainment', 'expense', 'movie', '#6A1B9A'),
    ('other-expense', 'Other expenses', 'expense', 'more_horiz', '#616161'),
    ('salary', 'Salary', 'income', 'payments', '#2E7D32'),
    ('bonus', 'Bonus', 'income', 'card_giftcard', '#00897B'),
    ('other-income', 'Other income', 'income', 'more_horiz', '#558B2F'),
  ];
  for (var i = 0; i < categories.length; i++) {
    final (id, name, type, icon, color) = categories[i];
    await database.customStatement(
      '''INSERT INTO categories
         (id, name, type, icon_key, color_hex, sort_order, is_archived)
         VALUES (?, ?, ?, ?, ?, ?, 0)''',
      ['seed-$id', name, type, icon, color, i],
    );
  }
  await database.customStatement(
    "INSERT INTO app_settings (key, value) VALUES ('theme_mode', 'system')",
  );
}
