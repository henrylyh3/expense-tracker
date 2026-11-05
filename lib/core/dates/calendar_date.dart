import '../models/ledger_types.dart';

/// A user's selected calendar day. Never converted between time zones.
class CalendarDate {
  CalendarDate._(this.year, this.month, this.day);

  factory CalendarDate.parse(String input) {
    if (!RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(input)) {
      throw const LedgerException('Choose a date in YYYY-MM-DD format.');
    }
    final parts = input.split('-').map(int.parse).toList();
    final normalized = DateTime.utc(parts[0], parts[1], parts[2]);
    if (parts[0] < 1 ||
        parts[0] > 9999 ||
        normalized.year != parts[0] ||
        normalized.month != parts[1] ||
        normalized.day != parts[2]) {
      throw const LedgerException('Choose a valid calendar date.');
    }
    return CalendarDate._(parts[0], parts[1], parts[2]);
  }

  factory CalendarDate.fromDateTime(DateTime value) => CalendarDate.parse(
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
  );

  factory CalendarDate.today() => CalendarDate.fromDateTime(DateTime.now());
  final int year;
  final int month;
  final int day;

  DateTime toLocalDateTime() => DateTime(year, month, day);

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
