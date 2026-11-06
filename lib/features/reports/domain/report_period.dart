import '../../../core/dates/calendar_date.dart';
import '../../../core/models/ledger_types.dart';

class ReportPeriod {
  ReportPeriod.month(this.year, int value) : month = value, isTrip = false {
    _validate();
  }
  ReportPeriod.year(this.year) : month = null, isTrip = false {
    _validate();
  }

  ReportPeriod.trip() : year = 1, month = null, isTrip = true;

  final bool isTrip;
  final int year;
  final int? month;
  bool get isYear => month == null && !isTrip;

  void _validate() {
    if (year < 1 ||
        year > 9999 ||
        (month != null && (month! < 1 || month! > 12))) {
      throw const LedgerException('Choose a valid report year and month.');
    }
  }

  CalendarDate get start => CalendarDate.parse(
    '${year.toString().padLeft(4, '0')}-${(month ?? 1).toString().padLeft(2, '0')}-01',
  );

  /// Null is the end of supported calendar history, not a five-digit date that
  /// would sort incorrectly against SQLite's fixed-width YYYY-MM-DD strings.
  CalendarDate? get endExclusive {
    if (isTrip) return null;
    final nextYear = isYear || month == 12 ? year + 1 : year;
    if (nextYear > 9999) return null;
    final nextMonth = isYear || month == 12 ? 1 : month! + 1;
    return CalendarDate.parse(
      '${nextYear.toString().padLeft(4, '0')}-${nextMonth.toString().padLeft(2, '0')}-01',
    );
  }

  CalendarDate get lastDay => CalendarDate.fromDateTime(
    DateTime.utc(year, isYear ? 13 : month! + 1, 0),
  );
  int get bucketCount => isTrip
      ? 0
      : isYear
      ? 12
      : lastDay.day;

  bool contains(CalendarDate date) =>
      date.toString().compareTo(start.toString()) >= 0 &&
      (endExclusive == null ||
          date.toString().compareTo(endExclusive.toString()) < 0);

  ReportPeriod? shift(int offset) {
    if (isTrip) return null;
    if (isYear) {
      final value = year + offset;
      return value < 1 || value > 9999 ? null : ReportPeriod.year(value);
    }
    final value = (year - 1) * 12 + month! - 1 + offset;
    return value < 0 || value >= 9999 * 12
        ? null
        : ReportPeriod.month(value ~/ 12 + 1, value % 12 + 1);
  }

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod &&
      other.year == year &&
      other.month == month &&
      other.isTrip == isTrip;
  @override
  int get hashCode => Object.hash(year, month, isTrip);
}
