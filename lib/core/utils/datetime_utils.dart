import 'package:intl/intl.dart';

class DateTimeUtils {
  /// Bangladesh timezone offset is UTC+6
  static const Duration bdOffset = Duration(hours: 6);

  /// Converts any UTC or local DateTime to Bangladesh Local DateTime (UTC+6)
  static DateTime toBangladeshTime(DateTime utcOrLocalTime) {
    final utc = utcOrLocalTime.toUtc();
    return utc.add(bdOffset);
  }

  /// Formats DateTime into Bangladesh local format (e.g., "24 Oct 2026, 02:30 PM")
  static String formatBdDateTime(DateTime dateTime) {
    final bdTime = toBangladeshTime(dateTime);
    return DateFormat('dd MMM yyyy, hh:mm a').format(bdTime);
  }

  /// Formats Date into Bangladesh local format (e.g., "24 Oct 2026")
  static String formatBdDate(DateTime dateTime) {
    final bdTime = toBangladeshTime(dateTime);
    return DateFormat('dd MMM yyyy').format(bdTime);
  }

  /// Formats Time into 12-hour format with AM/PM (e.g., "10:00 AM")
  static String formatBdTime(DateTime dateTime) {
    final bdTime = toBangladeshTime(dateTime);
    return DateFormat('hh:mm a').format(bdTime);
  }
}
