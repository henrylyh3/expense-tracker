import '../../../core/models/ledger_types.dart';
import '../../../core/validation/input_validation.dart';

/// Category management projection, including its current reference count.
class LedgerCategory {
  const LedgerCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.colorHex,
    required this.sortOrder,
    required this.isArchived,
    required this.usageCount,
  });

  final String id;
  final String name;
  final TransactionType type;
  final String iconKey;
  final String colorHex;
  final int sortOrder;
  final bool isArchived;
  final int usageCount;
  bool get isUsed => usageCount > 0;
}

class CategoryDraft {
  CategoryDraft({
    required String name,
    required this.type,
    required String iconKey,
    required String colorHex,
  }) : name = requiredText(name, label: 'Category name', maxLength: 80),
       iconKey = validateIconKey(iconKey),
       colorHex = validateColorHex(colorHex);

  final String name;
  final TransactionType type;
  final String iconKey;
  final String colorHex;

  static String validateIconKey(String input) {
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(input)) {
      throw const LedgerException('Choose a valid category icon.');
    }
    return input;
  }

  static String validateColorHex(String input) {
    final value = input.trim().toUpperCase();
    if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)) {
      throw const LedgerException('Enter a color in #RRGGBB format.');
    }
    return value;
  }
}
