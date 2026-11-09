import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../models/admin_audit_log.dart';
import '../models/booking.dart';
import '../models/complaint.dart';
import '../models/parking_spot.dart';
import '../models/user_profile.dart';

class AdminDashboardStats {
  final int totalUsers;
  final int pendingSpots;
  final int approvedSpots;
  final int rejectedSpots;
  final int totalBookings;
  final int openComplaints;

  AdminDashboardStats({
    required this.totalUsers,
    required this.pendingSpots,
    required this.approvedSpots,
    required this.rejectedSpots,
    required this.totalBookings,
    required this.openComplaints,
  });
}

class AdminRepository {
  static SupabaseClient get _client => SupabaseService.client;

  /// Check if current authenticated user has admin role in Supabase profiles
  static Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _client
          .from('profiles')
          .select('account_type')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return false;
      return response['account_type'] == 'admin';
    } catch (e) {
      debugPrint('Error verifying admin status: $e');
      return false;
    }
  }

  /// Fetch dashboard statistics for Admin
  static Future<AdminDashboardStats> fetchAdminDashboardStats() async {
    final usersRes = await _client.from('profiles').select('id');
    final spotsRes = await _client.from('parking_spots').select('id, approval_status');
    final bookingsRes = await _client.from('bookings').select('id');
    final complaintsRes = await _client.from('complaints').select('id, status');

    final spotList = spotsRes as List;
    final complaintList = complaintsRes as List;

    return AdminDashboardStats(
      totalUsers: (usersRes as List).length,
      pendingSpots: spotList.where((s) => s['approval_status'] == 'pending').length,
      approvedSpots: spotList.where((s) => s['approval_status'] == 'approved').length,
      rejectedSpots: spotList.where((s) => s['approval_status'] == 'rejected').length,
      totalBookings: (bookingsRes as List).length,
      openComplaints: complaintList.where((c) => c['status'] == 'open' || c['status'] == 'investigating').length,
    );
  }

  /// Fetch all spots for admin review (filtered by status)
  static Future<List<ParkingSpot>> fetchSpotsForAdmin({String? statusFilter}) async {
    var query = _client.from('parking_spots').select();

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('approval_status', statusFilter);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((json) => ParkingSpot.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Moderate a parking spot (Approve, Reject with Reason, or Suspend)
  static Future<void> moderateSpot({
    required String adminId,
    required String spotId,
    required String newStatus, // 'approved' | 'rejected' | 'suspended'
    String? reason,
  }) async {
    final updateData = <String, dynamic>{
      'approval_status': newStatus,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (newStatus == 'rejected' && reason != null) {
      updateData['rules'] = 'REJECTION REASON: $reason';
    }

    await _client.from('parking_spots').update(updateData).eq('id', spotId);

    final details = <String, dynamic>{
      'new_status': newStatus,
    };
    if (reason != null) {
      details['reason'] = reason;
    }

    // Log admin audit action
    await logAdminAction(
      adminId: adminId,
      action: 'spot_moderation_$newStatus',
      targetType: 'parking_spot',
      targetId: spotId,
      details: details,
    );
  }

  /// Fetch user profiles for admin search & management
  static Future<List<UserProfile>> fetchUsersForAdmin({String? searchQuery}) async {
    var query = _client.from('profiles').select();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = searchQuery.trim();
      query = query.or('full_name.ilike.%$term%,phone.ilike.%$term%');
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((json) => UserProfile.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch complaints for admin resolution
  static Future<List<Complaint>> fetchComplaintsForAdmin({String? statusFilter}) async {
    var query = _client.from('complaints').select();

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((json) => Complaint.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Update complaint status and add admin notes
  static Future<void> updateComplaint({
    required String adminId,
    required String complaintId,
    required String status, // 'open' | 'investigating' | 'resolved' | 'dismissed'
    String? adminNotes,
  }) async {
    await _client.from('complaints').update({
      'status': status,
      'admin_notes': adminNotes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', complaintId);

    final details = <String, dynamic>{
      'status': status,
    };
    if (adminNotes != null) {
      details['admin_notes'] = adminNotes;
    }

    await logAdminAction(
      adminId: adminId,
      action: 'complaint_updated_$status',
      targetType: 'complaint',
      targetId: complaintId,
      details: details,
    );
  }

  /// Fetch all bookings across platform for moderation/support
  static Future<List<Booking>> fetchAllBookingsForAdmin() async {
    final response = await _client
        .from('bookings')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Booking.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch admin audit logs
  static Future<List<AdminAuditLog>> fetchAdminAuditLogs() async {
    final response = await _client
        .from('admin_audit_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List)
        .map((json) => AdminAuditLog.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Helper to insert record into admin_audit_logs
  static Future<void> logAdminAction({
    required String adminId,
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic> details = const {},
  }) async {
    try {
      await _client.from('admin_audit_logs').insert({
        'admin_id': adminId,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'details': details,
      });
    } catch (e) {
      debugPrint('Error logging admin action: $e');
    }
  }
}
