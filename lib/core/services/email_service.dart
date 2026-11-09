import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'supabase_service.dart';

class EmailService {
  /// Send or resend signup verification email to the user's email address
  static Future<void> sendVerificationEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      throw ArgumentError('Email address cannot be empty.');
    }

    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) {
      throw StateError(
        'Supabase is not configured with valid project credentials. Please update SUPABASE_URL and SUPABASE_ANON_KEY in your .env file.',
      );
    }

    try {
      await AuthService.resendVerificationEmail(cleanEmail);
      debugPrint('Verification email requested for $cleanEmail via Supabase Auth');
    } catch (e) {
      debugPrint('Error sending verification email: $e');
      rethrow;
    }
  }

  /// Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      throw ArgumentError('Email address cannot be empty.');
    }

    try {
      await AuthService.sendPasswordResetEmail(cleanEmail);
      debugPrint('Password reset email sent to $cleanEmail');
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }
}
