import 'package:flutter/material.dart';

// Named constant icons retain release-mode icon tree shaking. Unknown imported
// keys fall back gracefully instead of constructing runtime IconData codepoints.
const categoryIcons = <String, IconData>{
  'restaurant': Icons.restaurant,
  'shopping_bag': Icons.shopping_bag,
  'directions_bus': Icons.directions_bus,
  'receipt_long': Icons.receipt_long,
  'medical_services': Icons.medical_services,
  'movie': Icons.movie,
  'payments': Icons.payments,
  'card_giftcard': Icons.card_giftcard,
  'home': Icons.home,
  'flight': Icons.flight,
  'school': Icons.school,
  'work': Icons.work,
  'savings': Icons.savings,
  'more_horiz': Icons.more_horiz,
};

Color categoryColor(String hex) => Color(
  0xFF000000 | (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x616161),
);
