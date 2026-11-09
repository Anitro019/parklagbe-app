import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
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

  /// Fetch public approved and active parking spots
  static Future<List<ParkingSpot>> fetchPublicSpots({
    String? searchQuery,
    String? vehicleType,
    double? maxHourlyPrice,
    String? district,
  }) async {
    var query = _client
        .from('parking_spots')
        .select()
        .eq('approval_status', 'approved')
        .eq('is_active', true);

    // Filter by Search Term (Area, Address, District, or Title)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = searchQuery.trim();
      query = query.or('area.ilike.%$term%,address.ilike.%$term%,title.ilike.%$term%,district.ilike.%$term%');
    }

    // Filter by District
    if (district != null && district.trim().isNotEmpty) {
      query = query.eq('district', district.trim());
    }

    // Filter by max hourly price
    if (maxHourlyPrice != null && maxHourlyPrice > 0) {
      query = query.lte('hourly_price', maxHourlyPrice);
    }

    final response = await query.order('created_at', ascending: false);

    List<ParkingSpot> spots = (response as List)
        .map((json) => ParkingSpot.fromJson(json as Map<String, dynamic>))
        .toList();

    // Filter by Vehicle Type array if specified
    if (vehicleType != null && vehicleType.isNotEmpty) {
      spots = spots.where((s) => s.vehicleTypes.contains(vehicleType)).toList();
    }

    return spots;
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
          .from('profiles')
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

    return (response as List)
        .map((json) => Review.fromJson(json as Map<String, dynamic>))
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
        .toList();

    // Preserve recent view order
    spots.sort((a, b) => history.indexOf(a.id).compareTo(history.indexOf(b.id)));
    return spots;
  }
}
