import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parklagbee/core/utils/datetime_utils.dart';
import 'package:parklagbee/core/utils/time_slot_calculator.dart';
import 'package:parklagbee/data/models/parking_spot.dart';

void main() {
  group('ParkLagbee Dynamic Time-Slot & Operational Hours Tests', () {
    test(
      'Availability schedule includes exact times on one day and across days',
      () {
        expect(
          DateTimeUtils.formatAvailabilitySchedule(
            availableFrom: DateTime.utc(2026, 11, 13, 4),
            availableTo: DateTime.utc(2026, 11, 13, 10, 58),
            availableHoursStart: '10:00:00',
            availableHoursEnd: '16:58:00',
          ),
          '13 Nov 2026, 10:00 AM – 4:58 PM',
        );
        expect(
          DateTimeUtils.formatAvailabilitySchedule(
            availableFrom: DateTime.utc(2026, 11, 13, 4),
            availableTo: DateTime.utc(2026, 11, 15, 10, 58),
            availableHoursStart: '10:00:00',
            availableHoursEnd: '16:58:00',
          ),
          '13 Nov 2026, 10:00 AM – 15 Nov 2026, 4:58 PM',
        );
      },
    );

    test('Time slots honor exact listing start and end dates and times', () {
      final spot = ParkingSpot(
        id: 'spot-id',
        ownerId: 'owner-id',
        title: 'Test spot',
        address: 'Test address',
        division: 'Dhaka',
        district: 'Dhaka',
        area: 'Gulshan',
        vehicleTypes: const ['car'],
        capacity: 1,
        availableHoursStart: '09:00:00',
        availableHoursEnd: '18:00:00',
        availableDays: const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
        availableFrom: DateTime.utc(2099, 1, 10, 4),
        availableTo: DateTime.utc(2099, 1, 12, 11),
        facilities: const [],
        advanceRequirementPercentage: 0,
        approvalStatus: 'approved',
        isActive: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      final firstDayRanges = TimeSlotCalculator.calculateAvailableRanges(
        spot: spot,
        date: DateTime(2099, 1, 10),
        activeBookingsOnDate: const [],
      );
      final finalDayRanges = TimeSlotCalculator.calculateAvailableRanges(
        spot: spot,
        date: DateTime(2099, 1, 12),
        activeBookingsOnDate: const [],
      );
      final outsideRange = TimeSlotCalculator.calculateAvailableRanges(
        spot: spot,
        date: DateTime(2099, 1, 13),
        activeBookingsOnDate: const [],
      );

      expect(firstDayRanges.single.start, const TimeOfDay(hour: 10, minute: 0));
      expect(firstDayRanges.single.end, const TimeOfDay(hour: 18, minute: 0));
      expect(finalDayRanges.single.start, const TimeOfDay(hour: 9, minute: 0));
      expect(finalDayRanges.single.end, const TimeOfDay(hour: 17, minute: 0));
      expect(outsideRange, isEmpty);
    });

    test(
      'Dynamic duration calculation math without hardcoded default hours',
      () {
        final start = DateTime(2026, 10, 24, 10, 0); // 10:00 AM
        final end = DateTime(2026, 10, 24, 15, 30); // 3:30 PM (5.5 hours)

        final diffMinutes = end.difference(start).inMinutes;
        final durationHours = diffMinutes / 60.0;

        const hourlyRate = 60.0;
        final totalPrice = durationHours * hourlyRate;

        expect(durationHours, equals(5.5));
        expect(totalPrice, equals(330.0));
      },
    );

    test('Operational hours boundary validation check', () {
      const opStart = TimeOfDay(hour: 10, minute: 0); // 10:00 AM
      const opEnd = TimeOfDay(hour: 17, minute: 0); // 05:00 PM

      bool isTimeWithinBounds(
        TimeOfDay target,
        TimeOfDay start,
        TimeOfDay end,
      ) {
        final targetMins = target.hour * 60 + target.minute;
        final startMins = start.hour * 60 + start.minute;
        final endMins = end.hour * 60 + end.minute;
        return targetMins >= startMins && targetMins <= endMins;
      }

      // 11:30 AM -> Inside bounds
      expect(
        isTimeWithinBounds(
          const TimeOfDay(hour: 11, minute: 30),
          opStart,
          opEnd,
        ),
        isTrue,
      );

      // 09:00 AM -> Outside bounds
      expect(
        isTimeWithinBounds(const TimeOfDay(hour: 9, minute: 0), opStart, opEnd),
        isFalse,
      );

      // 06:00 PM -> Outside bounds
      expect(
        isTimeWithinBounds(
          const TimeOfDay(hour: 18, minute: 0),
          opStart,
          opEnd,
        ),
        isFalse,
      );
    });

    test('Adjacent booking time windows non-overlap calculation', () {
      final booking1Start = DateTime(2026, 10, 24, 10, 0);
      final booking1End = DateTime(2026, 10, 24, 12, 0);

      final booking2Start = DateTime(
        2026,
        10,
        24,
        12,
        0,
      ); // Adjacent start at 12:00 PM
      final booking2End = DateTime(2026, 10, 24, 17, 0);

      bool checkOverlap(DateTime s1, DateTime e1, DateTime s2, DateTime e2) {
        return s1.isBefore(e2) && e1.isAfter(s2);
      }

      // 10:00-12:00 and 12:00-17:00 do NOT overlap!
      expect(
        checkOverlap(booking1Start, booking1End, booking2Start, booking2End),
        isFalse,
      );
    });
  });
}
