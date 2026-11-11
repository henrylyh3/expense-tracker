import '../money/display_currency.dart';

String formatSharedTripTotal(Map<String, dynamic> snapshot) {
  final total = int.parse(snapshot['total_myr_minor'] as String);
  final selected = snapshot['default_currency'];
  if (selected != null) {
    for (final row in snapshot['currencies'] as List) {
      if (row['id'] == selected) {
        if (row['code'] == 'MYR') break;
        return DisplayCurrency(
          row['code'] as String,
          row['precision'] as int,
          row['rate'] as String,
        ).format(total);
      }
    }
  }
  return DisplayCurrency.myr.format(total);
}
