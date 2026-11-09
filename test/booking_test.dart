import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParkLagbee Booking Engine Logic Tests', () {
    test('Hourly price calculation test (2 hours @ ৳30/hr = ৳60)', () {
      const double hourlyRate = 30.0;
      const double durationHours = 2.0;

      final double totalPrice = durationHours * hourlyRate;
      expect(totalPrice, equals(60.0));
    });

    test('Advance requirement calculation test (20% of ৳60 = ৳12)', () {
      const double totalPrice = 60.0;
      const double advancePercentage = 20.0;

      final double advanceAmount = totalPrice * (advancePercentage / 100.0);
      final double dueOnArrival = totalPrice - advanceAmount;

      expect(advanceAmount, equals(12.0));
      expect(dueOnArrival, equals(48.0));
    });

    test('Adjacent booking time window non-overlap check (10:00-11:00 vs 11:00-13:00)', () {
      // Booking A: 10:00 - 11:00
      final startA = DateTime.utc(2026, 10, 24, 10, 0);
      final endA = DateTime.utc(2026, 10, 24, 11, 0);

      // Booking B (Adjacent): 11:00 - 13:00
      final startB = DateTime.utc(2026, 10, 24, 11, 0);
      final endB = DateTime.utc(2026, 10, 24, 13, 0);

      // Overlap formula: start1 < end2 AND end1 > start2
      final bool overlaps = (startA.isBefore(endB)) && (endA.isAfter(startB));

      // Adjacent times MUST NOT overlap!
      expect(overlaps, isFalse);
    });

    test('Overlapping booking time window check (10:00-12:00 vs 11:00-13:00)', () {
      // Booking A: 10:00 - 12:00
      final startA = DateTime.utc(2026, 10, 24, 10, 0);
      final endA = DateTime.utc(2026, 10, 24, 12, 0);

      // Booking B (Overlapping): 11:00 - 13:00
      final startB = DateTime.utc(2026, 10, 24, 11, 0);
      final endB = DateTime.utc(2026, 10, 24, 13, 0);

      final bool overlaps = (startA.isBefore(endB)) && (endA.isAfter(startB));

      // Overlapping times MUST overlap
      expect(overlaps, isTrue);
    });
  });
}
