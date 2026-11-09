class Complaint {
  final String id;
  final String reporterId;
  final String? spotId;
  final String? bookingId;
  final String subject;
  final String description;
  final String status; // 'open' | 'investigating' | 'resolved' | 'dismissed'
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Complaint({
    required this.id,
    required this.reporterId,
    this.spotId,
    this.bookingId,
    required this.subject,
    required this.description,
    required this.status,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      spotId: json['spot_id'] as String?,
      bookingId: json['booking_id'] as String?,
      subject: json['subject'] as String,
      description: json['description'] as String,
      status: json['status'] as String? ?? 'open',
      adminNotes: json['admin_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reporter_id': reporterId,
      'spot_id': spotId,
      'booking_id': bookingId,
      'subject': subject,
      'description': description,
      'status': status,
      'admin_notes': adminNotes,
    };
  }
}
