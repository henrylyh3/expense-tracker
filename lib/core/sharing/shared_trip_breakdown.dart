import '../../features/reports/domain/financial_report.dart';
import '../money/money.dart';

class SharedTripBreakdown {
  const SharedTripBreakdown(this.currencyTotals, this.categories);

  final List<Money> currencyTotals;
  final List<CategorySpending> categories;

  static Map<String, Object?> encode(FinancialReport report) => {
    'currencies': [
      for (final total in report.currencyTotals)
        {
          'code': total.currencyCode,
          'precision': total.decimalPlaces,
          'minor': total.minorUnits.toString(),
        },
    ],
    'categories': [
      for (final category in report.categories)
        {
          'id': category.id,
          'name': category.name,
          'color': category.colorHex,
          'icon': category.iconKey,
          'minor': category.amountMinor.toString(),
          'count': category.count,
        },
    ],
  };

  static SharedTripBreakdown? fromSnapshot(Map<Object?, Object?> snapshot) {
    if (!snapshot.containsKey('breakdown')) return null;
    final breakdown = snapshot['breakdown'];
    if (breakdown is! Map) throw const FormatException('Invalid trip summary');

    List<Map<Object?, Object?>> rows(String field) {
      final value = breakdown[field];
      if (value is! List ||
          value.length > 5000 ||
          value.any((row) => row is! Map)) {
        throw const FormatException('Invalid trip summary rows');
      }
      return value.cast<Map<Object?, Object?>>();
    }

    String text(Object? value, int limit) {
      if (value is! String ||
          value.isEmpty ||
          value.runes.length > limit ||
          value.contains('\u0000')) {
        throw const FormatException('Invalid trip summary text');
      }
      return value;
    }

    int minor(Object? value) {
      final amount = text(value, 19);
      if (!RegExp(r'^\d+$').hasMatch(amount)) {
        throw const FormatException('Invalid trip summary amount');
      }
      return Money.checkedMinorUnits(BigInt.parse(amount));
    }

    final currencies = <Money>[];
    final codes = <String>{};
    for (final row in rows('currencies')) {
      final code = text(row['code'], 3);
      final precision = row['precision'];
      if (precision is! int || !codes.add(code)) {
        throw const FormatException('Invalid trip summary currency');
      }
      currencies.add(
        Money.fromMinor(
          minorUnits: minor(row['minor']),
          currencyCode: code,
          decimalPlaces: precision,
        ),
      );
    }
    final categories = <CategorySpending>[];
    final ids = <String>{};
    var total = BigInt.zero;
    var count = 0;
    for (final row in rows('categories')) {
      final id = text(row['id'], 80);
      final color = text(row['color'], 7);
      final rowCount = row['count'];
      if (!ids.add(id) ||
          !RegExp(r'^#?[A-Fa-f0-9]{6}$').hasMatch(color) ||
          rowCount is! int ||
          rowCount <= 0 ||
          rowCount > (snapshot['count'] as int) - count) {
        throw const FormatException('Invalid trip summary category');
      }
      final amount = minor(row['minor']);
      total += BigInt.from(amount);
      count += rowCount;
      categories.add(
        CategorySpending(
          id: id,
          name: text(row['name'], 80),
          colorHex: color,
          iconKey: text(row['icon'], 80),
          amountMinor: amount,
          count: rowCount,
        ),
      );
    }
    if (count != snapshot['count'] ||
        total != BigInt.parse(snapshot['total_myr_minor'] as String)) {
      throw const FormatException('Trip summary totals do not match');
    }
    return SharedTripBreakdown(currencies, categories);
  }
}
