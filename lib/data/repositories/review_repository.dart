import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import 'content_moderation_repository.dart';
import '../models/review.dart';

class RatingSummary {
  final double averageRating;
  final int totalReviews;

  RatingSummary({required this.averageRating, required this.totalReviews});
}

class ReviewRepository {
  static SupabaseClient get _client => SupabaseService.client;

  /// Submit two-way feedback for an accepted booking.
  static Future<Review> submitReview({
    required String bookingId,
    required int rating,
    String? reviewText,
  }) async {
    final response = await _client.rpc(
      'submit_two_way_review',
      params: {
        'p_booking_id': bookingId,
        'p_rating': rating,
        'p_review_text': reviewText,
      },
    );

    return Review.fromJson(response);
  }

  /// Check if user has already left a review for a specific booking
  static Future<Review?> fetchUserReviewForBooking({
    required String bookingId,
    required String userId,
  }) async {
    final response = await _client
        .from('reviews')
        .select('*, profiles:reviewer_id(full_name, avatar_url)')
        .eq('booking_id', bookingId)
        .eq('reviewer_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Review.fromJson(response);
  }

  /// Fetch public reviews for a parking spot
  static Future<List<Review>> fetchSpotReviews(String spotId) async {
    final response = await _client
        .from('reviews')
        .select('*, profiles:reviewer_id(full_name, avatar_url)')
        .eq('spot_id', spotId)
        .order('created_at', ascending: false);

    final blockedUserIds =
        await ContentModerationRepository.fetchBlockedUserIds();
    return (response as List)
        .map((json) => Review.fromJson(json as Map<String, dynamic>))
        .where(
          (review) =>
              (review.reviewerRole == 'vehicle_owner' ||
                  review.reviewerRole == 'customer') &&
              !blockedUserIds.contains(review.reviewerId),
        )
        .toList();
  }

  /// Fetch public reviews received by a user (Driver or Host)
  static Future<List<Review>> fetchUserReceivedReviews(String userId) async {
    final response = await _client
        .from('reviews')
        .select('*, profiles:reviewer_id(full_name, avatar_url)')
        .eq('target_user_id', userId)
        .order('created_at', ascending: false);

    final blockedUserIds =
        await ContentModerationRepository.fetchBlockedUserIds();
    return (response as List)
        .map((json) => Review.fromJson(json as Map<String, dynamic>))
        .where((review) => !blockedUserIds.contains(review.reviewerId))
        .toList();
  }

  /// Calculate spot rating average and count
  static Future<RatingSummary> fetchSpotRatingSummary(String spotId) async {
    final reviews = await fetchSpotReviews(spotId);
    if (reviews.isEmpty) {
      return RatingSummary(averageRating: 0.0, totalReviews: 0);
    }

    final totalScore = reviews.fold<int>(0, (sum, r) => sum + r.rating);
    final avg = totalScore / reviews.length;
    return RatingSummary(averageRating: avg, totalReviews: reviews.length);
  }

  /// Calculate user (Vehicle Owner or Host) rating average and count
  static Future<RatingSummary> fetchUserRatingSummary(String userId) async {
    final reviews = await fetchUserReceivedReviews(userId);
    if (reviews.isEmpty) {
      return RatingSummary(averageRating: 0.0, totalReviews: 0);
    }

    final totalScore = reviews.fold<int>(0, (sum, r) => sum + r.rating);
    final avg = totalScore / reviews.length;
    return RatingSummary(averageRating: avg, totalReviews: reviews.length);
  }
}
