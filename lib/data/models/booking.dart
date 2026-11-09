class Booking {
  final String id;
  final String bookingReference;
  final String customerId;
  final String spotId;
  final String vehicleType;
  final String? vehicleNumber;
  final DateTime bookingDate;
  final DateTime startTime;
  final DateTime endTime;
  final double durationHours;
  final String rentalType; // 'hourly' | 'daily' | 'monthly'
  final Map<String, dynamic> priceBreakdown;
  final double totalPrice;
  final double advanceAmount;
  final String bookingStatus; // 'pending' | 'confirmed' | 'active' | 'completed' | 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  Booking({
    required this.id,
    required this.bookingReference,
    required this.customerId,
    required this.spotId,
    required this.vehicleType,
    this.vehicleNumber,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.rentalType,
    required this.priceBreakdown,
    required this.totalPrice,
    required this.advanceAmount,
    required this.bookingStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      bookingReference: json['booking_reference'] as String,
      customerId: json['customer_id'] as String,
      spotId: json['spot_id'] as String,
      vehicleType: json['vehicle_type'] as String,
      vehicleNumber: json['vehicle_number'] as String?,
      bookingDate: DateTime.parse(json['booking_date'] as String),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      durationHours: (json['duration_hours'] as num).toDouble(),
      rentalType: json['rental_type'] as String? ?? 'hourly',
      priceBreakdown: Map<String, dynamic>.from(json['price_breakdown'] ?? {}),
      totalPrice: (json['total_price'] as num).toDouble(),
      advanceAmount: (json['advance_amount'] as num?)?.toDouble() ?? 0.0,
      bookingStatus: json['booking_status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_reference': bookingReference,
      'customer_id': customerId,
      'spot_id': spotId,
      'vehicle_type': vehicleType,
      'vehicle_number': vehicleNumber,
      'booking_date': bookingDate.toIso8601String().split('T').first,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'duration_hours': durationHours,
      'rental_type': rentalType,
      'price_breakdown': priceBreakdown,
      'total_price': totalPrice,
      'advance_amount': advanceAmount,
      'booking_status': bookingStatus,
    };
  }
}
