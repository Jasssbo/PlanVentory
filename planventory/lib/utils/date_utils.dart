import 'package:intl/intl.dart';

/// Date utility functions
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');

  /// Format date as dd/MM/yyyy
  static String formatDate(DateTime date) => _dateFormat.format(date);

  /// Format date as dd/MM/yyyy HH:mm
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  /// Format as "Month Year" (e.g., "April 2024")
  static String formatMonthYear(DateTime date) => _monthYearFormat.format(date);

  /// Check if two date ranges overlap
  static bool doRangesOverlap(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
  ) {
    return start1.isBefore(end2) && end1.isAfter(start2);
  }

  /// Get the start of a day
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get the end of a day
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  /// Get the first day of a month
  static DateTime firstDayOfMonth(int year, int month) {
    return DateTime(year, month, 1);
  }

  /// Get the last day of a month
  static DateTime lastDayOfMonth(int year, int month) {
    return DateTime(year, month + 1, 0, 23, 59, 59);
  }
}
