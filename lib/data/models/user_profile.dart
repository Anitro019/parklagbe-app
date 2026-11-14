class UserProfile {
  final String id;
  final String fullName;
  final String? phone;
  final String? address;
  final String? avatarUrl;
  final String accountType; // 'driver' | 'host' | 'admin'
  final bool isVerified;
  final String? nidNumber;
  final String? drivingLicenseNumber;
  final String? verificationDocUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.fullName,
    this.phone,
    this.address,
    this.avatarUrl,
    required this.accountType,
    this.isVerified = false,
    this.nidNumber,
    this.drivingLicenseNumber,
    this.verificationDocUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      accountType: json['account_type'] as String? ?? 'driver',
      isVerified: json['is_verified'] as bool? ?? false,
      nidNumber: json['nid_number'] as String?,
      drivingLicenseNumber: json['driving_license_number'] as String?,
      verificationDocUrl: json['verification_doc_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'address': address,
      'avatar_url': avatarUrl,
      'account_type': accountType,
      'is_verified': isVerified,
      'nid_number': nidNumber,
      'driving_license_number': drivingLicenseNumber,
      'verification_doc_url': verificationDocUrl,
    };
  }

  bool get isAdmin => accountType == 'admin';
  bool get isHost => accountType == 'host';
  bool get isDriver => accountType == 'driver';
}
