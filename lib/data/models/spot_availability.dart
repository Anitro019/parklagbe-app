class SpotAvailability {
  final String id;
  final String spotId;
  final DateTime startDate;
  final DateTime endDate;
  final String dailyStartTime;
  final String dailyEndTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  SpotAvailability({
    required this.id,
    required this.spotId,
    required this.startDate,
    required this.endDate,
    required this.dailyStartTime,
    required this.dailyEndTime,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SpotAvailability.fromJson(Map<String, dynamic> json) {
    return SpotAvailability(
      id: json['id'] as String,
      spotId: json['spot_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      dailyStartTime: json['daily_start_time'] as String? ?? '00:00:00',
      dailyEndTime: json['daily_end_time'] as String? ?? '23:59:59',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spot_id': spotId,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'daily_start_time': dailyStartTime,
      'daily_end_time': dailyEndTime,
    };
  }

  bool get isExpired {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return endDate.isBefore(today);
  }
}
