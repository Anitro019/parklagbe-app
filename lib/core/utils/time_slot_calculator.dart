import 'package:flutter/material.dart';

import 'datetime_utils.dart';
import '../../data/models/booking.dart';
import '../../data/models/parking_spot.dart';

class TimeRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeRange(this.start, this.end);

  int get startMinutes => start.hour * 60 + start.minute;
  int get endMinutes => end.hour * 60 + end.minute;
  int get durationMinutes => endMinutes - startMinutes;

  String format(BuildContext context) {
    return '${start.format(context)} - ${end.format(context)}';
  }
}

class TimeSlotCalculator {
  /// Parse time string "HH:mm:ss" or "HH:mm" to TimeOfDay
  static TimeOfDay parseTime(String timeStr, TimeOfDay fallback) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return fallback;
    }
  }

  /// Convert DateTime to TimeOfDay
  static TimeOfDay fromDateTime(DateTime dt) {
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  /// Calculates available time slot ranges for a spot on a given date considering active bookings
  static List<TimeRange> calculateAvailableRanges({
    required ParkingSpot spot,
    required DateTime date,
    required List<Booking> activeBookingsOnDate,
  }) {
    final selectedDate = DateTime.utc(date.year, date.month, date.day);
    final availableFrom = spot.effectiveAvailableFrom == null
        ? null
        : DateTimeUtils.toBangladeshTime(spot.effectiveAvailableFrom!);
    final availableTo = spot.effectiveAvailableTo == null
        ? null
        : DateTimeUtils.toBangladeshTime(spot.effectiveAvailableTo!);

    DateTime dateOnly(DateTime value) =>
        DateTime.utc(value.year, value.month, value.day);

    if (spot.isExpired ||
        (availableFrom != null &&
            selectedDate.isBefore(dateOnly(availableFrom))) ||
        (availableTo != null && selectedDate.isAfter(dateOnly(availableTo)))) {
      return [];
    }

    final opStart = parseTime(
      spot.availableHoursStart,
      const TimeOfDay(hour: 0, minute: 0),
    );
    final opEnd = parseTime(
      spot.availableHoursEnd,
      const TimeOfDay(hour: 23, minute: 59),
    );

    int windowStartMins = opStart.hour * 60 + opStart.minute;
    int windowEndMins = opEnd.hour * 60 + opEnd.minute;

    if (windowEndMins <= windowStartMins) {
      windowEndMins = 24 * 60; // Midnight default
    }

    if (availableFrom != null && dateOnly(availableFrom) == selectedDate) {
      final availabilityStart = availableFrom.hour * 60 + availableFrom.minute;
      if (availabilityStart > windowStartMins) {
        windowStartMins = availabilityStart;
      }
    }
    if (availableTo != null && dateOnly(availableTo) == selectedDate) {
      final availabilityEnd = availableTo.hour * 60 + availableTo.minute;
      if (availabilityEnd < windowEndMins) {
        windowEndMins = availabilityEnd;
      }
    }

    final now = DateTimeUtils.toBangladeshTime(DateTime.now());
    if (dateOnly(now) == selectedDate) {
      final currentMinute = now.hour * 60 + now.minute + 1;
      if (currentMinute > windowStartMins) {
        windowStartMins = currentMinute;
      }
    }

    if (windowEndMins <= windowStartMins) return [];

    // Filter active bookings that overlap with this window
    final bookedRanges = <TimeRange>[];
    for (final booking in activeBookingsOnDate) {
      if (booking.bookingStatus == 'rejected' ||
          booking.bookingStatus == 'cancelled') {
        continue;
      }

      final localStart = DateTimeUtils.toBangladeshTime(booking.startTime);
      final localEnd = DateTimeUtils.toBangladeshTime(booking.endTime);
      final startMins = localStart.hour * 60 + localStart.minute;
      final endMins = localEnd.hour * 60 + localEnd.minute;

      final clampedStart = startMins.clamp(windowStartMins, windowEndMins);
      final clampedEnd = endMins.clamp(windowStartMins, windowEndMins);

      if (clampedEnd > clampedStart) {
        bookedRanges.add(
          TimeRange(
            TimeOfDay(hour: clampedStart ~/ 60, minute: clampedStart % 60),
            TimeOfDay(hour: clampedEnd ~/ 60, minute: clampedEnd % 60),
          ),
        );
      }
    }

    // Sort booked ranges by start time
    bookedRanges.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    // Calculate free unbooked gaps
    final availableRanges = <TimeRange>[];
    int currentPointer = windowStartMins;

    for (final booked in bookedRanges) {
      if (booked.startMinutes > currentPointer) {
        // We have an available gap before this booking
        availableRanges.add(
          TimeRange(
            TimeOfDay(hour: currentPointer ~/ 60, minute: currentPointer % 60),
            TimeOfDay(
              hour: booked.startMinutes ~/ 60,
              minute: booked.startMinutes % 60,
            ),
          ),
        );
      }
      if (booked.endMinutes > currentPointer) {
        currentPointer = booked.endMinutes;
      }
    }

    if (currentPointer < windowEndMins) {
      availableRanges.add(
        TimeRange(
          TimeOfDay(hour: currentPointer ~/ 60, minute: currentPointer % 60),
          TimeOfDay(hour: windowEndMins ~/ 60, minute: windowEndMins % 60),
        ),
      );
    }

    // Filter out gaps shorter than 30 minutes
    return availableRanges.where((r) => r.durationMinutes >= 30).toList();
  }

  /// Check if a specific date is completely fully booked for a given spot
  static bool isDateFullyBooked({
    required ParkingSpot spot,
    required DateTime date,
    required List<Booking> activeBookingsOnDate,
  }) {
    final ranges = calculateAvailableRanges(
      spot: spot,
      date: date,
      activeBookingsOnDate: activeBookingsOnDate,
    );
    return ranges.isEmpty;
  }

  /// Format available ranges display string (e.g. "Available Hours Left: 12:00 PM - 5:00 PM")
  static String formatAvailabilityStatus(
    BuildContext context, {
    required ParkingSpot spot,
    required DateTime date,
    required List<Booking> activeBookingsOnDate,
  }) {
    if (spot.isExpired) {
      return 'Availability Expired';
    }

    final ranges = calculateAvailableRanges(
      spot: spot,
      date: date,
      activeBookingsOnDate: activeBookingsOnDate,
    );

    if (ranges.isEmpty) {
      return 'Fully Booked / Not Available';
    }

    final formattedList = ranges.map((r) => r.format(context)).join(', ');
    return 'Available Hours Left: $formattedList';
  }
}
