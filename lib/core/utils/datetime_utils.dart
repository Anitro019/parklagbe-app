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

  static String formatAvailabilitySchedule({
    required DateTime? availableFrom,
    required DateTime? availableTo,
    required String availableHoursStart,
    required String availableHoursEnd,
  }) {
    final dailyHours =
        '${_formatClock(availableHoursStart)} – ${_formatClock(availableHoursEnd)}';

    if (availableFrom != null && availableTo != null) {
      final start = toBangladeshTime(availableFrom);
      final end = toBangladeshTime(availableTo);
      final sameDay =
          start.year == end.year &&
          start.month == end.month &&
          start.day == end.day;
      return sameDay
          ? '${DateFormat('dd MMM yyyy').format(start)}, ${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}'
          : '${_formatAvailabilityDateTime(start)} – ${_formatAvailabilityDateTime(end)}';
    }

    if (availableFrom != null) {
      return 'From ${_formatAvailabilityDateTime(toBangladeshTime(availableFrom))} · daily $dailyHours';
    }
    if (availableTo != null) {
      return 'Daily $dailyHours · until ${_formatAvailabilityDateTime(toBangladeshTime(availableTo))}';
    }
    return 'Daily $dailyHours · no end date';
  }

  static String _formatAvailabilityDateTime(DateTime bdTime) =>
      '${DateFormat('dd MMM yyyy').format(bdTime)}, ${DateFormat('h:mm a').format(bdTime)}';

  static String _formatClock(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateFormat('hh:mm a').format(DateTime(2000, 1, 1, hour, minute));
  }
}
