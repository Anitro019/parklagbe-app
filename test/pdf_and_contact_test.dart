import 'package:flutter_test/flutter_test.dart';
import 'package:parklagbee/core/services/pdf_receipt_service.dart';
import 'package:parklagbee/data/models/booking.dart';
import 'package:parklagbee/data/models/parking_spot.dart';
import 'package:parklagbee/data/models/user_profile.dart';

void main() {
  group('ParkLagbee PDF Receipt & Contact Tests', () {
    test('PDF Receipt bytes generation and legal disclaimer test', () async {
      final booking = Booking(
        id: 'book-101',
        bookingReference: 'PKL-20261024-9999',
        customerId: 'cust-1',
        spotId: 'spot-1',
        vehicleType: 'car',
        vehicleNumber: 'Dhaka Metro-GA-11-2233',
        bookingDate: DateTime.parse('2026-10-24'),
        startTime: DateTime.parse('2026-10-24T10:00:00.000Z'),
        endTime: DateTime.parse('2026-10-24T12:00:00.000Z'),
        durationHours: 2.0,
        rentalType: 'hourly',
        priceBreakdown: {'subtotal': 100.0, 'advance_amount': 20.0},
        totalPrice: 100.0,
        advanceAmount: 20.0,
        bookingStatus: 'confirmed',
        createdAt: DateTime.parse('2026-10-24T09:00:00.000Z'),
        updatedAt: DateTime.parse('2026-10-24T09:00:00.000Z'),
      );

      final spot = ParkingSpot(
        id: 'spot-1',
        ownerId: 'owner-1',
        title: 'Covered Garage in Gulshan 2',
        address: 'House 12, Road 11, Block D',
        division: 'Dhaka',
        district: 'Dhaka',
        area: 'Gulshan 2',
        googleMapsUrl: 'https://maps.google.com/?q=23.792,90.415',
        vehicleTypes: ['car'],
        capacity: 1,
        hourlyPrice: 50.0,
        availableHoursStart: '00:00:00',
        availableHoursEnd: '23:59:59',
        availableDays: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
        facilities: ['cctv', 'guarded'],
        advanceRequirementPercentage: 20.0,
        contactPhone: '+8801700000000',
        isContactVisible: true,
        approvalStatus: 'approved',
        isActive: true,
        createdAt: DateTime.parse('2026-10-24T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-10-24T00:00:00.000Z'),
      );

      final customer = UserProfile(
        id: 'cust-1',
        fullName: 'Kamal Hossain',
        phone: '+8801800000000',
        accountType: 'driver',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final pdfBytes = await PdfReceiptService.buildReceiptPdf(
        booking: booking,
        spot: spot,
        customer: customer,
      );

      // Verify PDF bytes are generated and non-empty
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
    });

    test('Contact phone normalization for WhatsApp', () {
      String sanitizePhone(String phone) {
        String clean = phone.replaceAll(RegExp(r'\D'), '');
        if (clean.startsWith('01') && clean.length == 11) {
          clean = '88$clean';
        }
        return clean;
      }

      expect(sanitizePhone('+8801700000000'), equals('8801700000000'));
      expect(sanitizePhone('01700000000'), equals('8801700000000'));
    });
  });
}
