class ParkingSpot {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String address;
  final String division;
  final String district;
  final String area;
  final double? latitude;
  final double? longitude;
  final String? googleMapsUrl;
  final List<String> vehicleTypes;
  final int capacity;
  final double? hourlyPrice;
  final double? dailyPrice;
  final double? monthlyPrice;
  final String availableHoursStart;
  final String availableHoursEnd;
  final List<String> availableDays;
  final String? rules;
  final List<String> facilities;
  final double advanceRequirementPercentage;
  final String? contactPhone;
  final bool isContactVisible;
  final String approvalStatus; // 'pending' | 'approved' | 'rejected' | 'suspended'
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ParkingSpot({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    required this.address,
    required this.division,
    required this.district,
    required this.area,
    this.latitude,
    this.longitude,
    this.googleMapsUrl,
    required this.vehicleTypes,
    required this.capacity,
    this.hourlyPrice,
    this.dailyPrice,
    this.monthlyPrice,
    required this.availableHoursStart,
    required this.availableHoursEnd,
    required this.availableDays,
    this.rules,
    required this.facilities,
    required this.advanceRequirementPercentage,
    this.contactPhone,
    this.isContactVisible = true,
    required this.approvalStatus,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ParkingSpot.fromJson(Map<String, dynamic> json) {
    return ParkingSpot(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      address: json['address'] as String,
      division: json['division'] as String,
      district: json['district'] as String,
      area: json['area'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      googleMapsUrl: json['google_maps_url'] as String?,
      vehicleTypes: List<String>.from(json['vehicle_types'] ?? []),
      capacity: (json['capacity'] as num?)?.toInt() ?? 1,
      hourlyPrice: (json['hourly_price'] as num?)?.toDouble(),
      dailyPrice: (json['daily_price'] as num?)?.toDouble(),
      monthlyPrice: (json['monthly_price'] as num?)?.toDouble(),
      availableHoursStart: json['available_hours_start'] as String? ?? '00:00:00',
      availableHoursEnd: json['available_hours_end'] as String? ?? '23:59:59',
      availableDays: List<String>.from(json['available_days'] ?? []),
      rules: json['rules'] as String?,
      facilities: List<String>.from(json['facilities'] ?? []),
      advanceRequirementPercentage: (json['advance_requirement_percentage'] as num?)?.toDouble() ?? 0.0,
      contactPhone: json['contact_phone'] as String?,
      isContactVisible: json['is_contact_visible'] as bool? ?? true,
      approvalStatus: json['approval_status'] as String? ?? 'pending',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'address': address,
      'division': division,
      'district': district,
      'area': area,
      'latitude': latitude,
      'longitude': longitude,
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
      'approval_status': approvalStatus,
      'is_active': isActive,
    };
  }

  bool get isApproved => approvalStatus == 'approved';
}
