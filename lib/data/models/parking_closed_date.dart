class ParkingClosedDate {
  final String id;
  final String spotId;
  final DateTime closedDate;
  final String? reason;
  final DateTime createdAt;

  ParkingClosedDate({
    required this.id,
    required this.spotId,
    required this.closedDate,
    this.reason,
    required this.createdAt,
  });

  factory ParkingClosedDate.fromJson(Map<String, dynamic> json) {
    return ParkingClosedDate(
      id: json['id'] as String,
      spotId: json['spot_id'] as String,
      closedDate: DateTime.parse(json['closed_date'] as String),
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spot_id': spotId,
      'closed_date': closedDate.toIso8601String().split('T').first,
      'reason': reason,
    };
  }
}
