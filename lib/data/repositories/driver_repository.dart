import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../core/utils/time_slot_calculator.dart';
import 'content_moderation_repository.dart';
import 'spot_repository.dart';
import '../models/parking_photo.dart';
import '../models/parking_spot.dart';
import '../models/review.dart';
import '../models/user_profile.dart';

class SpotWithOwner {
  final ParkingSpot spot;
  final UserProfile? ownerProfile;

  SpotWithOwner({required this.spot, this.ownerProfile});
}

class DriverRepository {
  static SupabaseClient get _client => SupabaseService.client;
  static const String _recentSpotsKey = 'recently_viewed_spot_ids';

  /// Fetch public approved and active parking spots with advanced filtering
  static Future<List<ParkingSpot>> fetchPublicSpots({
    String? searchQuery,
    String? vehicleType,
    double? minHourlyPrice,
    double? maxHourlyPrice,
    String? area,
    String? district,
  }) async {
    var query = _client
        .from('parking_spots')
        .select()
        .eq('approval_status', 'approved')
        .eq('is_active', true);
    query = query.or(
      'available_to.is.null,available_to.gt.${DateTime.now().toUtc().toIso8601String()}',
    );

    // Filter by Search Term (Area, Address, District, or Title)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = searchQuery.trim();
      query = query.or(
        'area.ilike.%$term%,address.ilike.%$term%,title.ilike.%$term%,district.ilike.%$term%',
      );
    }

    // Filter by Area / Neighborhood
    if (area != null && area.trim().isNotEmpty && area != 'All Areas') {
      query = query.ilike('area', '%${area.trim()}%');
    }

    // Filter by District
    if (district != null && district.trim().isNotEmpty) {
      query = query.eq('district', district.trim());
    }

    // Filter by min & max hourly price
    if (minHourlyPrice != null && minHourlyPrice > 0) {
      query = query.gte('hourly_price', minHourlyPrice);
    }

    if (maxHourlyPrice != null && maxHourlyPrice > 0) {
      query = query.lte('hourly_price', maxHourlyPrice);
    }

    final response = await query.order('created_at', ascending: false);

    List<ParkingSpot> spots = (response as List)
        .map((json) => ParkingSpot.fromJson(json as Map<String, dynamic>))
        .toList();

    // Filter out spots whose availability has expired or ALL available dates are fully booked (Requirement 1)
    final availableSpots = <ParkingSpot>[];
    for (final spot in spots) {
      if (spot.isExpired) continue;

      final isCompletelyFull = await isSpotCompletelyFullyBooked(spot);
      if (!isCompletelyFull) {
        availableSpots.add(spot);
      }
    }
    spots = availableSpots;

    // Filter by Vehicle Type array if specified
    if (vehicleType != null &&
        vehicleType.isNotEmpty &&
        vehicleType != 'both') {
      spots = spots.where((s) => s.vehicleTypes.contains(vehicleType)).toList();
    }

    final blockedUserIds =
        await ContentModerationRepository.fetchBlockedUserIds();
    spots = spots
        .where((spot) => !blockedUserIds.contains(spot.ownerId))
        .toList();

    return spots;
  }

  /// Check if ALL available dates for a spot are fully booked (Hides spot when 0 available dates remain)
  static Future<bool> isSpotCompletelyFullyBooked(ParkingSpot spot) async {
    if (spot.isExpired) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final startDate =
        (spot.availableStartDate != null &&
            spot.availableStartDate!.isAfter(today))
        ? DateTime(
            spot.availableStartDate!.year,
            spot.availableStartDate!.month,
            spot.availableStartDate!.day,
          )
        : today;

    final endDate = spot.availableEndDate != null
        ? DateTime(
            spot.availableEndDate!.year,
            spot.availableEndDate!.month,
            spot.availableEndDate!.day,
          )
        : today.add(const Duration(days: 14)); // Check 14-day window

    if (endDate.isBefore(startDate)) return true;

    int totalValidDates = 0;
    int fullyBookedDates = 0;

    DateTime current = startDate;
    while (!current.isAfter(endDate) && totalValidDates < 30) {
      totalValidDates++;
      final bookingsOnDate =
          await SpotRepository.fetchActiveBookingsForSpotDate(spot.id, current);
      final isFull = TimeSlotCalculator.isDateFullyBooked(
        spot: spot,
        date: current,
        activeBookingsOnDate: bookingsOnDate,
      );
      if (isFull) {
        fullyBookedDates++;
      } else {
        // Found at least 1 available date! Spot is NOT completely fully booked.
        return false;
      }
      current = current.add(const Duration(days: 1));
    }

    return totalValidDates > 0 && fullyBookedDates == totalValidDates;
  }

  /// Fetch full spot details with owner profile info
  static Future<SpotWithOwner> fetchSpotDetails(String spotId) async {
    final spotRes = await _client
        .from('parking_spots')
        .select()
        .eq('id', spotId)
        .single();

    final spot = ParkingSpot.fromJson(spotRes);

    UserProfile? owner;
    try {
      final ownerRes = await _client
          .from('public_profiles')
          .select()
          .eq('id', spot.ownerId)
          .maybeSingle();

      if (ownerRes != null) {
        owner = UserProfile.fromJson(ownerRes);
      }
    } catch (e) {
      debugPrint('Error fetching spot owner profile: $e');
    }

    return SpotWithOwner(spot: spot, ownerProfile: owner);
  }

  /// Fetch photos for a parking spot
  static Future<List<ParkingPhoto>> fetchSpotPhotos(String spotId) async {
    final response = await _client
        .from('parking_photos')
        .select()
        .eq('spot_id', spotId)
        .order('display_order', ascending: true);

    return (response as List)
        .map((json) => ParkingPhoto.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch genuine reviews for a parking spot
  static Future<List<Review>> fetchSpotReviews(String spotId) async {
    final response = await _client
        .from('reviews')
        .select()
        .eq('spot_id', spotId)
        .order('created_at', ascending: false);

    final blockedUserIds =
        await ContentModerationRepository.fetchBlockedUserIds();
    return (response as List)
        .map((json) => Review.fromJson(json as Map<String, dynamic>))
        .where((review) => !blockedUserIds.contains(review.reviewerId))
        .toList();
  }

  /// Save spot ID to local Recently Viewed History
  static Future<void> saveRecentlyViewedSpot(String spotId) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_recentSpotsKey) ?? [];

    history.remove(spotId);
    history.insert(0, spotId);

    // Keep top 10 recent
    if (history.length > 10) {
      history.removeLast();
    }

    await prefs.setStringList(_recentSpotsKey, history);
  }

  /// Fetch recently viewed spots if actual local history exists
  static Future<List<ParkingSpot>> fetchRecentlyViewedSpots() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_recentSpotsKey) ?? [];

    if (history.isEmpty) return [];

    final response = await _client
        .from('parking_spots')
        .select()
        .inFilter('id', history)
        .eq('approval_status', 'approved')
        .eq('is_active', true);

    final spots = (response as List)
        .map((json) => ParkingSpot.fromJson(json as Map<String, dynamic>))
        .where((spot) => !spot.isExpired)
        .toList();

    final blockedUserIds =
        await ContentModerationRepository.fetchBlockedUserIds();
    spots.removeWhere((spot) => blockedUserIds.contains(spot.ownerId));

    // Preserve recent view order
    spots.sort(
      (a, b) => history.indexOf(a.id).compareTo(history.indexOf(b.id)),
    );
    return spots;
  }
}
