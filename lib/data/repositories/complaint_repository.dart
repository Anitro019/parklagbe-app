import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../models/complaint.dart';

class ComplaintRepository {
  static SupabaseClient get _client => SupabaseService.client;

  /// Submit complaint or report via server RPC
  static Future<Complaint> submitComplaint({
    required String subject,
    required String description,
    String? spotId,
    String? bookingId,
  }) async {
    final response = await _client.rpc('submit_complaint', params: {
      'p_subject': subject,
      'p_description': description,
      'p_spot_id': spotId,
      'p_booking_id': bookingId,
    });

    return Complaint.fromJson(response as Map<String, dynamic>);
  }

  /// Fetch complaints submitted by current user
  static Future<List<Complaint>> fetchUserComplaints(String userId) async {
    final response = await _client
        .from('complaints')
        .select()
        .eq('reporter_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Complaint.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
