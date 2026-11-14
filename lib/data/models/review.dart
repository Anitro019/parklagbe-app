class Review {
  final String id;
  final String bookingId;
  final String reviewerId;
  final String? revieweeId;
  final String
  reviewerRole; // 'customer' | 'owner' | 'vehicle_owner' | 'spot_owner'
  final String spotId;
  final int rating;
  final String? reviewText;
  final String? reviewerName;
  final String? reviewerAvatarUrl;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.bookingId,
    required this.reviewerId,
    this.revieweeId,
    required this.reviewerRole,
    required this.spotId,
    required this.rating,
    this.reviewText,
    this.reviewerName,
    this.reviewerAvatarUrl,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final profile =
        json['profiles'] as Map<String, dynamic>? ??
        json['reviewer_profile'] as Map<String, dynamic>?;

    return Review(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      reviewerId: json['reviewer_id'] as String,
      revieweeId:
          json['reviewee_id'] as String? ?? json['target_user_id'] as String?,
      reviewerRole: json['reviewer_role'] as String? ?? 'customer',
      spotId: json['spot_id'] as String,
      rating: (json['rating'] as num).toInt(),
      reviewText: (json['review_text'] ?? json['comment']) as String?,
      reviewerName: profile?['full_name'] as String?,
      reviewerAvatarUrl: profile?['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'reviewer_id': reviewerId,
      'target_user_id': revieweeId,
      'reviewer_role': reviewerRole,
      'spot_id': spotId,
      'rating': rating,
      'comment': reviewText,
    };
  }
}
