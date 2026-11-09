import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../models/review.dart';

class SpotRatingSummary {
  final double averageRating;
  final int totalReviews;

  SpotRatingSummary({required this.averageRating, required this.totalReviews});
}

class ReviewRepository {
  static SupabaseClient get _client => SupabaseService.client;

  /// Submit review for a completed booking via server RPC
  static Future<Review> submitReview({
    required String bookingId,
    required int rating,
    String? reviewText,
  }) async {
    final response = await _client.rpc('submit_review', params: {
      'p_booking_id': bookingId,
      'p_rating': rating,
      'p_review_text': reviewText,
    });

    return Review.fromJson(response as Map<String, dynamic>);
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

  /// Calculate spot rating average and count from real reviews
  static Future<SpotRatingSummary> fetchSpotRatingSummary(String spotId) async {
    final reviews = await fetchSpotReviews(spotId);
    if (reviews.isEmpty) {
      return SpotRatingSummary(averageRating: 0.0, totalReviews: 0);
    }

    final totalScore = reviews.fold<int>(0, (sum, r) => sum + r.rating);
    final avg = totalScore / reviews.length;
    return SpotRatingSummary(averageRating: avg, totalReviews: reviews.length);
  }
}
