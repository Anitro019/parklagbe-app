import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParkLagbee Dynamic Time-Slot & Operational Hours Tests', () {
    test('Dynamic duration calculation math without hardcoded default hours', () {
      final start = DateTime(2026, 10, 24, 10, 0); // 10:00 AM
      final end = DateTime(2026, 10, 24, 15, 30);   // 3:30 PM (5.5 hours)

      final diffMinutes = end.difference(start).inMinutes;
      final durationHours = diffMinutes / 60.0;

      const hourlyRate = 60.0;
      final totalPrice = durationHours * hourlyRate;

      expect(durationHours, equals(5.5));
      expect(totalPrice, equals(330.0));
    });

    test('Operational hours boundary validation check', () {
      const opStart = TimeOfDay(hour: 10, minute: 0); // 10:00 AM
      const opEnd = TimeOfDay(hour: 17, minute: 0);   // 05:00 PM

      bool isTimeWithinBounds(TimeOfDay target, TimeOfDay start, TimeOfDay end) {
        final targetMins = target.hour * 60 + target.minute;
        final startMins = start.hour * 60 + start.minute;
        final endMins = end.hour * 60 + end.minute;
        return targetMins >= startMins && targetMins <= endMins;
      }

      // 11:30 AM -> Inside bounds
      expect(isTimeWithinBounds(const TimeOfDay(hour: 11, minute: 30), opStart, opEnd), isTrue);

      // 09:00 AM -> Outside bounds
      expect(isTimeWithinBounds(const TimeOfDay(hour: 9, minute: 0), opStart, opEnd), isFalse);

      // 06:00 PM -> Outside bounds
      expect(isTimeWithinBounds(const TimeOfDay(hour: 18, minute: 0), opStart, opEnd), isFalse);
    });

    test('Adjacent booking time windows non-overlap calculation', () {
      final booking1Start = DateTime(2026, 10, 24, 10, 0);
      final booking1End = DateTime(2026, 10, 24, 12, 0);

      final booking2Start = DateTime(2026, 10, 24, 12, 0); // Adjacent start at 12:00 PM
      final booking2End = DateTime(2026, 10, 24, 17, 0);

      bool checkOverlap(DateTime s1, DateTime e1, DateTime s2, DateTime e2) {
        return s1.isBefore(e2) && e1.isAfter(s2);
      }

      // 10:00-12:00 and 12:00-17:00 do NOT overlap!
      expect(checkOverlap(booking1Start, booking1End, booking2Start, booking2End), isFalse);
    });
  });
}
