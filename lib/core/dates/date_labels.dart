import 'package:intl/intl.dart';

import 'calendar_date.dart';

// English is the current app language. intl bundles en_US date symbols by
// default, so these labels need neither locale initialization nor any I/O.
String monthYearLabel(CalendarDate date) =>
    DateFormat.yMMMM('en_US').format(_fields(date));
String monthLabel(CalendarDate date) =>
    DateFormat.MMM('en_US').format(_fields(date));
String dayLabel(CalendarDate date) =>
    DateFormat.d('en_US').format(_fields(date));

// UTC is only a stable field carrier here, never a conversion of the ledger day.
DateTime _fields(CalendarDate date) =>
    DateTime.utc(date.year, date.month, date.day);
