import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../models/booking.dart';
import '../models/parking_spot.dart';
import '../models/user_profile.dart';

class BookingWithCustomer {
  final Booking booking;
  final UserProfile? customerProfile;
  final ParkingSpot? spot;

  BookingWithCustomer({
    required this.booking,
    this.customerProfile,
    this.spot,
  });
}

class BookingRepository {
  static SupabaseClient get _client => SupabaseService.client;

  /// Call server RPC `create_booking` with pessimistic locking and server price calculation
  static Future<Booking> createBookingRequest({
    required String spotId,
    required String vehicleType,
    String? vehicleNumber,
    required DateTime bookingDate,
    required DateTime startTime,
    required DateTime endTime,
    String rentalType = 'hourly',
  }) async {
    final response = await _client.rpc('create_booking', params: {
      'p_spot_id': spotId,
      'p_vehicle_type': vehicleType,
      'p_vehicle_number': vehicleNumber,
      'p_booking_date': bookingDate.toIso8601String().split('T').first,
      'p_start_time': startTime.toUtc().toIso8601String(),
      'p_end_time': endTime.toUtc().toIso8601String(),
      'p_rental_type': rentalType,
    });

    return Booking.fromJson(response as Map<String, dynamic>);
  }

  /// Check server-side spot availability before opening booking dialog
  static Future<bool> checkAvailability({
    required String spotId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final response = await _client.rpc('check_spot_availability', params: {
      'p_spot_id': spotId,
      'p_start_time': startTime.toUtc().toIso8601String(),
      'p_end_time': endTime.toUtc().toIso8601String(),
    });

    return response as bool;
  }

  /// Fetch bookings for the logged-in customer
  static Future<List<Booking>> fetchCustomerBookings(String customerId) async {
    final response = await _client
        .from('bookings')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Booking.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch booking requests for spots owned by host with customer details
  static Future<List<BookingWithCustomer>> fetchHostBookings(String ownerId) async {
    // 1. Fetch spots owned by host
    final spotsRes = await _client
        .from('parking_spots')
        .select('id, title, area')
        .eq('owner_id', ownerId);

    final spotList = spotsRes as List;
    final spotIds = spotList.map((s) => s['id'] as String).toList();

    if (spotIds.isEmpty) return [];

    // 2. Fetch bookings for these spots
    final bookingsRes = await _client
        .from('bookings')
        .select()
        .inFilter('spot_id', spotIds)
        .order('created_at', ascending: false);

    final bookings = (bookingsRes as List)
        .map((json) => Booking.fromJson(json as Map<String, dynamic>))
        .toList();

    // 3. Attach customer profile details
    List<BookingWithCustomer> result = [];
    for (final booking in bookings) {
      UserProfile? customer;
      try {
        final custRes = await _client
            .from('profiles')
            .select()
            .eq('id', booking.customerId)
            .maybeSingle();

        if (custRes != null) {
          customer = UserProfile.fromJson(custRes);
        }
      } catch (e) {
        debugPrint('Error fetching customer profile for booking: $e');
      }

      result.add(BookingWithCustomer(booking: booking, customerProfile: customer));
    }

    return result;
  }

  /// Approve booking request (Spot owner)
  static Future<Booking> approveBooking(String bookingId) async {
    final response = await _client.rpc('approve_booking', params: {
      'p_booking_id': bookingId,
    });

    return Booking.fromJson(response as Map<String, dynamic>);
  }

  /// Reject booking request (Spot owner)
  static Future<Booking> rejectBooking(String bookingId, {String? reason}) async {
    final response = await _client.rpc('reject_booking', params: {
      'p_booking_id': bookingId,
      'p_reason': reason,
    });

    return Booking.fromJson(response as Map<String, dynamic>);
  }

  /// Complete booking (Spot owner or Admin)
  static Future<Booking> completeBooking(String bookingId) async {
    final response = await _client.rpc('complete_booking', params: {
      'p_booking_id': bookingId,
    });

    return Booking.fromJson(response as Map<String, dynamic>);
  }

  /// Cancel booking (Customer or Spot Owner)
  static Future<Booking> cancelBooking(String bookingId) async {
    final response = await _client.rpc('cancel_booking', params: {
      'p_booking_id': bookingId,
    });

    return Booking.fromJson(response as Map<String, dynamic>);
  }
}
