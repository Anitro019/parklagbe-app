import '../../core/services/supabase_service.dart';

class ContentModerationRepository {
  static Future<Set<String>> fetchBlockedUserIds() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return {};

    final rows = await SupabaseService.client
        .from('blocked_users')
        .select('blocked_user_id')
        .eq('blocker_id', userId);
    return (rows as List)
        .map((row) => row['blocked_user_id'] as String)
        .toSet();
  }

  static Future<void> reportContent({
    required String reason,
    String? reportedUserId,
    String? spotId,
    String? reviewId,
  }) async {
    final reporterId = SupabaseService.currentUser?.id;
    if (reporterId == null) throw StateError('Sign in to report content.');

    await SupabaseService.client.from('content_reports').insert({
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'spot_id': spotId,
      'review_id': reviewId,
      'reason': reason,
    });
  }

  static Future<void> blockUser(String blockedUserId) async {
    final blockerId = SupabaseService.currentUser?.id;
    if (blockerId == null) throw StateError('Sign in to block a user.');
    if (blockerId == blockedUserId) {
      throw StateError('You cannot block your own account.');
    }

    await SupabaseService.client
        .from('blocked_users')
        .upsert(
          {'blocker_id': blockerId, 'blocked_user_id': blockedUserId},
          onConflict: 'blocker_id,blocked_user_id',
          ignoreDuplicates: true,
        );
  }
}
