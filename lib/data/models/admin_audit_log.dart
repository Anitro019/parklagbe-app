class AdminAuditLog {
  final String id;
  final String? adminId;
  final String action;
  final String targetType;
  final String targetId;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  AdminAuditLog({
    required this.id,
    this.adminId,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.details,
    required this.createdAt,
  });

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    return AdminAuditLog(
      id: json['id'] as String,
      adminId: json['admin_id'] as String?,
      action: json['action'] as String,
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String,
      details: Map<String, dynamic>.from(json['details'] ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'admin_id': adminId,
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'details': details,
    };
  }
}
