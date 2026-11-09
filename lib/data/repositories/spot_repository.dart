import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../models/parking_photo.dart';
import '../models/parking_spot.dart';

class OwnerDashboardStats {
  final int totalListings;
  final int approvedListings;
  final int pendingListings;
  final int pendingBookings;
  final int confirmedBookings;
  final int completedBookings;

  OwnerDashboardStats({
    required this.totalListings,
    required this.approvedListings,
    required this.pendingListings,
    required this.pendingBookings,
    required this.confirmedBookings,
    required this.completedBookings,
  });
}

class SpotRepository {
  static SupabaseClient get _client => SupabaseService.client;

  /// Fetch all parking spots owned by current host
  static Future<List<ParkingSpot>> fetchOwnerSpots(String ownerId) async {
    final response = await _client
        .from('parking_spots')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => ParkingSpot.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch photos for a specific parking spot
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

  /// Fetch dashboard statistics for the parking spot owner
  static Future<OwnerDashboardStats> fetchOwnerDashboardStats(String ownerId) async {
    // 1. Fetch spots owned by this user
    final spotsResponse = await _client
        .from('parking_spots')
        .select('id, approval_status')
        .eq('owner_id', ownerId);

    final spotList = spotsResponse as List;
    final spotIds = spotList.map((s) => s['id'] as String).toList();

    int totalListings = spotList.length;
    int approvedListings = spotList.where((s) => s['approval_status'] == 'approved').length;
    int pendingListings = spotList.where((s) => s['approval_status'] == 'pending').length;

    int pendingBookings = 0;
    int confirmedBookings = 0;
    int completedBookings = 0;

    if (spotIds.isNotEmpty) {
      final bookingsResponse = await _client
          .from('bookings')
          .select('booking_status')
          .inFilter('spot_id', spotIds);

      final bookingList = bookingsResponse as List;
      pendingBookings = bookingList.where((b) => b['booking_status'] == 'pending').length;
      confirmedBookings = bookingList.where((b) => b['booking_status'] == 'confirmed' || b['booking_status'] == 'active').length;
      completedBookings = bookingList.where((b) => b['booking_status'] == 'completed').length;
    }

    return OwnerDashboardStats(
      totalListings: totalListings,
      approvedListings: approvedListings,
      pendingListings: pendingListings,
      pendingBookings: pendingBookings,
      confirmedBookings: confirmedBookings,
      completedBookings: completedBookings,
    );
  }

  /// Create a new Parking Spot with photos (Auto-approved)
  static Future<ParkingSpot> createSpot({
    required String ownerId,
    required String title,
    required String description,
    required String division,
    required String district,
    required String area,
    required String address,
    required String? googleMapsUrl,
    required List<String> vehicleTypes,
    required int capacity,
    required double? hourlyPrice,
    required double? dailyPrice,
    required double? monthlyPrice,
    required String availableHoursStart,
    required String availableHoursEnd,
    required List<String> availableDays,
    required String? rules,
    required List<String> facilities,
    required double advanceRequirementPercentage,
    String? contactPhone,
    bool isContactVisible = true,
    List<File>? newPhotoFiles,
    List<Uint8List>? newPhotoBytes,
  }) async {
    final spotData = <String, dynamic>{
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'division': division,
      'district': district,
      'area': area,
      'address': address,
      'google_maps_url': googleMapsUrl,
      'vehicle_types': vehicleTypes,
      'capacity': capacity,
      'hourly_price': hourlyPrice,
      'daily_price': dailyPrice,
      'monthly_price': monthlyPrice,
      'available_hours_start': availableHoursStart,
      'available_hours_end': availableHoursEnd,
      'available_days': availableDays,
      'rules': rules,
      'facilities': facilities,
      'advance_requirement_percentage': advanceRequirementPercentage,
      'contact_phone': contactPhone,
      'is_contact_visible': isContactVisible,
      'approval_status': 'approved', // Auto-approved directly upon creation
      'is_active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await _client
          .from('parking_spots')
          .insert(spotData)
          .select()
          .single();

      final createdSpot = ParkingSpot.fromJson(response);

      // Upload photos if provided
      await _uploadSpotPhotos(
        spotId: createdSpot.id,
        photoFiles: newPhotoFiles,
        photoBytesList: newPhotoBytes,
      );

      return createdSpot;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' || e.message.contains('contact_phone')) {
        debugPrint('Schema fallback: contact_phone column missing in PostgREST cache. Retrying without contact fields.');
        final fallbackData = Map<String, dynamic>.from(spotData)
          ..remove('contact_phone')
          ..remove('is_contact_visible');

        final response = await _client
            .from('parking_spots')
            .insert(fallbackData)
            .select()
            .single();

        final createdSpot = ParkingSpot.fromJson(response);

        await _uploadSpotPhotos(
          spotId: createdSpot.id,
          photoFiles: newPhotoFiles,
          photoBytesList: newPhotoBytes,
        );

        return createdSpot;
      }
      rethrow;
    }
  }

  /// Update an existing Parking Spot
  static Future<void> updateSpot({
    required String spotId,
    required String ownerId,
    required String title,
    required String description,
    required String division,
    required String district,
    required String area,
    required String address,
    required String? googleMapsUrl,
    required List<String> vehicleTypes,
    required int capacity,
    required double? hourlyPrice,
    required double? dailyPrice,
    required double? monthlyPrice,
    required String availableHoursStart,
    required String availableHoursEnd,
    required List<String> availableDays,
    required String? rules,
    required List<String> facilities,
    required double advanceRequirementPercentage,
    String? contactPhone,
    bool isContactVisible = true,
    List<File>? newPhotoFiles,
    List<Uint8List>? newPhotoBytes,
    List<String>? deletePhotoIds,
  }) async {
    // Delete photos if requested
    if (deletePhotoIds != null && deletePhotoIds.isNotEmpty) {
      for (final photoId in deletePhotoIds) {
        await _client.from('parking_photos').delete().eq('id', photoId);
      }
    }

    final spotData = <String, dynamic>{
      'title': title,
      'description': description,
      'division': division,
      'district': district,
      'area': area,
      'address': address,
      'google_maps_url': googleMapsUrl,
      'vehicle_types': vehicleTypes,
      'capacity': capacity,
      'hourly_price': hourlyPrice,
      'daily_price': dailyPrice,
      'monthly_price': monthlyPrice,
      'available_hours_start': availableHoursStart,
      'available_hours_end': availableHoursEnd,
      'available_days': availableDays,
      'rules': rules,
      'facilities': facilities,
      'advance_requirement_percentage': advanceRequirementPercentage,
      'contact_phone': contactPhone,
      'is_contact_visible': isContactVisible,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _client.from('parking_spots').update(spotData).eq('id', spotId).eq('owner_id', ownerId);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' || e.message.contains('contact_phone')) {
        debugPrint('Schema fallback: contact_phone column missing in PostgREST cache. Updating without contact fields.');
        final fallbackData = Map<String, dynamic>.from(spotData)
          ..remove('contact_phone')
          ..remove('is_contact_visible');

        await _client.from('parking_spots').update(fallbackData).eq('id', spotId).eq('owner_id', ownerId);
      } else {
        rethrow;
      }
    }

    // Upload new photos if provided
    await _uploadSpotPhotos(
      spotId: spotId,
      photoFiles: newPhotoFiles,
      photoBytesList: newPhotoBytes,
    );
  }

  /// Toggle spot active/inactive status (Temporarily Unavailable)
  static Future<void> toggleSpotActiveStatus(String spotId, String ownerId, bool isActive) async {
    await _client
        .from('parking_spots')
        .update({'is_active': isActive, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', spotId)
        .eq('owner_id', ownerId);
  }

  /// Check if spot can be deleted (No pending/confirmed/active bookings)
  static Future<bool> canDeleteSpot(String spotId) async {
    final response = await _client
        .from('bookings')
        .select('id')
        .eq('spot_id', spotId)
        .inFilter('booking_status', ['pending', 'confirmed', 'active']);

    final activeBookings = response as List;
    return activeBookings.isEmpty;
  }

  /// Delete spot if safe
  static Future<void> deleteSpot(String spotId, String ownerId) async {
    final canDelete = await canDeleteSpot(spotId);
    if (!canDelete) {
      throw StateError('Cannot delete listing because there are active or upcoming bookings. Instead, set the listing to "Temporarily Unavailable" (Inactive) to block new bookings.');
    }

    await _client.from('parking_spots').delete().eq('id', spotId).eq('owner_id', ownerId);
  }

  /// Private helper to upload photos to parking-photos bucket and save parking_photos record
  static Future<void> _uploadSpotPhotos({
    required String spotId,
    List<File>? photoFiles,
    List<Uint8List>? photoBytesList,
  }) async {
    if (kIsWeb && photoBytesList != null && photoBytesList.isNotEmpty) {
      for (int i = 0; i < photoBytesList.length; i++) {
        final storagePath = '$spotId/photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        await _client.storage.from('parking-photos').uploadBinary(
              storagePath,
              photoBytesList[i],
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
            );

        final publicUrl = _client.storage.from('parking-photos').getPublicUrl(storagePath);
        await _client.from('parking_photos').insert({
          'spot_id': spotId,
          'storage_path': publicUrl,
          'display_order': i,
        });
      }
    } else if (photoFiles != null && photoFiles.isNotEmpty) {
      for (int i = 0; i < photoFiles.length; i++) {
        final storagePath = '$spotId/photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        await _client.storage.from('parking-photos').upload(
              storagePath,
              photoFiles[i],
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
            );

        final publicUrl = _client.storage.from('parking-photos').getPublicUrl(storagePath);
        await _client.from('parking_photos').insert({
          'spot_id': spotId,
          'storage_path': publicUrl,
          'display_order': i,
        });
      }
    }
  }
}
