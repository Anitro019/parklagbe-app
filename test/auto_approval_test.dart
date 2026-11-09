import 'package:flutter_test/flutter_test.dart';
import 'package:parklagbee/data/models/parking_spot.dart';

void main() {
  group('ParkLagbee Spot Auto-Approval Tests', () {
    test('Parking spot defaults to approved status upon creation', () {
      final spot = ParkingSpot(
        id: 'spot-101',
        ownerId: 'owner-1',
        title: 'Uttara Sector 3 Parking',
        address: 'Road 7, Sector 3',
        division: 'Dhaka',
        district: 'Dhaka',
        area: 'Uttara',
        vehicleTypes: ['car', 'bike'],
        capacity: 2,
        hourlyPrice: 40.0,
        availableHoursStart: '00:00:00',
        availableHoursEnd: '23:59:59',
        availableDays: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
        facilities: ['cctv'],
        advanceRequirementPercentage: 10.0,
        approvalStatus: 'approved',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(spot.approvalStatus, equals('approved'));
      expect(spot.isActive, isTrue);
    });
  });
}
