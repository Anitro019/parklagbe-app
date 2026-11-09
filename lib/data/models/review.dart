class Review {
  final String id;
  final String bookingId;
  final String reviewerId;
  final String spotId;
  final int rating;
  final String? reviewText;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.bookingId,
    required this.reviewerId,
    required this.spotId,
    required this.rating,
    this.reviewText,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      reviewerId: json['reviewer_id'] as String,
      spotId: json['spot_id'] as String,
      rating: (json['rating'] as num).toInt(),
      reviewText: json['review_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'reviewer_id': reviewerId,
      'spot_id': spotId,
      'rating': rating,
      'review_text': reviewText,
    };
  }
}
