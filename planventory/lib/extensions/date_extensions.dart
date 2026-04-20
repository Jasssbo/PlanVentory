import 'package:intl/intl.dart';

/// Extensions on DateTime
extension DateTimeExtensions on DateTime {
  /// Format as dd/MM/yyyy
  String get formatted => DateFormat('dd/MM/yyyy').format(this);

  /// Format as dd/MM/yyyy HH:mm
  String get formattedWithTime => DateFormat('dd/MM/yyyy HH:mm').format(this);

  /// Format as "Mon, 5 Apr"
  String get shortFormatted => DateFormat('E, d MMM').format(this);

  /// Format as "Monday, April 5, 2026"
  String get longFormatted => DateFormat('EEEE, MMMM d, y').format(this);

  /// Format as "April 2026"
  String get monthYear => DateFormat('MMMM y').format(this);

  /// Format as "5 Apr"
  String get dayMonth => DateFormat('d MMM').format(this);

  /// Format time only as "14:30"
  String get timeOnly => DateFormat('HH:mm').format(this);

  /// Check if same day as another date
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// Check if today
  bool get isToday => isSameDay(DateTime.now());

  /// Check if tomorrow
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return isSameDay(tomorrow);
  }

  /// Check if yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(yesterday);
  }

  /// Get start of day (00:00:00)
  DateTime get startOfDay => DateTime(year, month, day);

  /// Get end of day (23:59:59)
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);

  /// Get first day of month
  DateTime get firstDayOfMonth => DateTime(year, month, 1);

  /// Get last day of month
  DateTime get lastDayOfMonth => DateTime(year, month + 1, 0);

  /// Get relative description (today, tomorrow, or formatted)
  String get relative {
    if (isToday) return 'Today';
    if (isTomorrow) return 'Tomorrow';
    if (isYesterday) return 'Yesterday';
    return shortFormatted;
  }
}
