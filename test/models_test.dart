import 'package:flutter_test/flutter_test.dart';
import 'package:parklagbee/core/utils/datetime_utils.dart';
import 'package:parklagbee/data/models/models.dart';

void main() {
  group('ParkLagbee Models & Timezone Tests', () {
    test('UserProfile JSON parsing test', () {
      final json = {
        'id': 'usr-123',
        'full_name': 'Rahim Uddin',
        'phone': '+8801700000000',
        'address': 'Dhanmondi, Dhaka',
        'account_type': 'host',
        'created_at': '2026-10-24T10:00:00.000Z',
        'updated_at': '2026-10-24T10:00:00.000Z',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.id, equals('usr-123'));
      expect(profile.fullName, equals('Rahim Uddin'));
      expect(profile.isHost, isTrue);
      expect(profile.isAdmin, isFalse);
    });

    test('ParkingSpot JSON parsing test', () {
      final json = {
        'id': 'spot-123',
        'owner_id': 'usr-123',
        'title': 'Secure Covered Parking in Gulshan 2',
        'address': 'Road 11, Gulshan 2',
        'division': 'Dhaka',
        'district': 'Dhaka',
        'area': 'Gulshan',
        'vehicle_types': ['car', 'suv'],
        'capacity': 2,
        'hourly_price': 100.0,
        'available_hours_start': '08:00:00',
        'available_hours_end': '22:00:00',
        'available_days': ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
        'facilities': ['cctv', 'guarded', 'covered'],
        'advance_requirement_percentage': 20.0,
        'approval_status': 'approved',
        'is_active': true,
        'created_at': '2026-10-24T10:00:00.000Z',
        'updated_at': '2026-10-24T10:00:00.000Z',
      };

      final spot = ParkingSpot.fromJson(json);
      expect(spot.id, equals('spot-123'));
      expect(spot.area, equals('Gulshan'));
      expect(spot.hourlyPrice, equals(100.0));
      expect(spot.isApproved, isTrue);
    });

    test('Bangladesh DateTime conversion test (UTC+6)', () {
      final utcTime = DateTime.parse('2026-10-24T04:00:00.000Z');
      final bdTime = DateTimeUtils.toBangladeshTime(utcTime);

      // UTC 04:00 + 6 hours = 10:00 AM BD local time
      expect(bdTime.hour, equals(10));
      final formatted = DateTimeUtils.formatBdDateTime(utcTime);
      expect(formatted, contains('10:00 AM'));
    });
  });
}
