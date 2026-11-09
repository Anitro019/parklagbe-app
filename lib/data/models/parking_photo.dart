class ParkingPhoto {
  final String id;
  final String spotId;
  final String storagePath;
  final int displayOrder;
  final DateTime createdAt;

  ParkingPhoto({
    required this.id,
    required this.spotId,
    required this.storagePath,
    required this.displayOrder,
    required this.createdAt,
  });

  factory ParkingPhoto.fromJson(Map<String, dynamic> json) {
    return ParkingPhoto(
      id: json['id'] as String,
      spotId: json['spot_id'] as String,
      storagePath: json['storage_path'] as String,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spot_id': spotId,
      'storage_path': storagePath,
      'display_order': displayOrder,
    };
  }
}
