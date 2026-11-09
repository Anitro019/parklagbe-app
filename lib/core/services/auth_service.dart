import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/user_profile.dart';
import 'supabase_service.dart';

class AuthService {
  /// Get current auth session
  static Session? get currentSession {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) return null;
    return SupabaseService.client.auth.currentSession;
  }

  /// Stream of auth changes
  static Stream<AuthState> get authStateChanges {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) {
      return const Stream<AuthState>.empty();
    }
    return SupabaseService.client.auth.onAuthStateChange;
  }

  /// Current user
  static User? get currentUser {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) return null;
    return SupabaseService.client.auth.currentUser;
  }

  /// Current user email verified status
  static bool get isEmailVerified {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) return false;
    final user = currentUser;
    if (user == null) return false;
    return user.emailConfirmedAt != null;
  }

  /// Sign Up with Email, Password, Full Name, Address, Account Type, Optional Phone and Optional Profile Photo
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String phone = '',
    required String address,
    required String accountType,
    File? avatarFile,
    Uint8List? avatarBytes,
  }) async {
    if (SupabaseService.isPlaceholderConfig) {
      throw StateError('Please configure real Supabase credentials before registering accounts. Pass --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...');
    }

    final safeRole = (accountType == 'host') ? 'host' : 'driver';

    final response = await SupabaseService.client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'parklagbee://login',
      data: {
        'full_name': fullName,
        'phone': phone,
        'address': address,
        'account_type': safeRole,
        'role': safeRole,
      },
    );

    final user = response.user;

    // With "Confirm email" on, Supabase hides whether an email is already registered:
    // it returns a fake user with no identities and sends NO email. Surface that clearly.
    if (user != null && (user.identities?.isEmpty ?? false)) {
      throw Exception(
        'An account with this email already exists. Please sign in, or use "Forgot Password" if you cannot access it.',
      );
    }

    if (user != null) {
      String? avatarUrl;

      // Handle profile photo upload if provided
      if (avatarFile != null || avatarBytes != null) {
        try {
          avatarUrl = await _uploadAvatar(
            userId: user.id,
            avatarFile: avatarFile,
            avatarBytes: avatarBytes,
          );
        } catch (e) {
          debugPrint('Error uploading profile photo during signup: $e');
        }
      }

      // Ensure profile record is updated with address and avatarUrl
      try {
        final profileData = <String, dynamic>{
          'id': user.id,
          'full_name': fullName,
          'phone': phone,
          'address': address,
          'account_type': safeRole,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        if (avatarUrl != null) {
          profileData['avatar_url'] = avatarUrl;
        }

        await SupabaseService.client.from('profiles').upsert(profileData);
      } catch (e) {
        debugPrint('Error updating profile row during signup: $e');
      }
    }

    return response;
  }

  /// Resend Signup Verification Email
  static Future<void> resendVerificationEmail(String email) async {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) return;
    try {
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: 'parklagbee://login',
      );
    } on AuthRetryableFetchException catch (e) {
      debugPrint('AuthRetryableFetchException during resendVerificationEmail: $e');
      throw Exception('Network error connecting to auth server. Please check internet connection.');
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Sign In with Email and Password
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (SupabaseService.isPlaceholderConfig) {
      throw StateError('Please configure real Supabase credentials before signing in.');
    }

    try {
      return await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthRetryableFetchException catch (e) {
      debugPrint('AuthRetryableFetchException during signInWithEmail: $e');
      throw Exception('Network error connecting to auth server. Please check internet connection.');
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Initiate Password Reset Email
  static Future<void> sendPasswordResetEmail(String email) async {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) {
      throw StateError('Please configure real Supabase credentials before resetting password.');
    }
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : 'parklagbee://reset-password',
      );
    } on AuthRetryableFetchException catch (e) {
      debugPrint('AuthRetryableFetchException during sendPasswordResetEmail: $e');
      throw Exception('Network error connecting to auth server. Please check internet connection.');
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Update User Password (used during Password Reset flow)
  static Future<UserResponse> updatePassword(String newPassword) async {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) {
      throw StateError('Supabase is not initialized with real credentials.');
    }
    return await SupabaseService.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Delete User Account (Google Play Requirement)
  static Future<void> deleteAccount() async {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) {
      throw StateError('Supabase is not initialized with real credentials.');
    }
    await SupabaseService.client.rpc('delete_user_account');
    await signOut();
  }

  /// Sign Out
  static Future<void> signOut() async {
    if (SupabaseService.isInitialized && !SupabaseService.isPlaceholderConfig) {
      await SupabaseService.client.auth.signOut();
    }
  }

  /// Fetch User Profile
  static Future<UserProfile?> fetchUserProfile() async {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) return null;

    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching user profile from Supabase: $e');
      return null;
    }
  }

  /// Update User Profile Details
  static Future<void> updateUserProfile({
    required String fullName,
    required String phone,
    required String address,
    File? avatarFile,
    Uint8List? avatarBytes,
  }) async {
    final user = currentUser;
    if (user == null) throw StateError('Not logged in');

    String? avatarUrl;
    if (avatarFile != null || avatarBytes != null) {
      avatarUrl = await _uploadAvatar(
        userId: user.id,
        avatarFile: avatarFile,
        avatarBytes: avatarBytes,
      );
    }

    final updates = <String, dynamic>{
      'id': user.id,
      'full_name': fullName,
      'phone': phone,
      'address': address,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (avatarUrl != null) {
      updates['avatar_url'] = avatarUrl;
    }

    await SupabaseService.client.from('profiles').upsert(updates);
  }

  /// Private helper to upload avatar to profile-photos bucket
  static Future<String> _uploadAvatar({
    required String userId,
    File? avatarFile,
    Uint8List? avatarBytes,
  }) async {
    final storagePath = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (kIsWeb && avatarBytes != null) {
      await SupabaseService.client.storage.from('profile-photos').uploadBinary(
            storagePath,
            avatarBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
    } else if (avatarFile != null) {
      await SupabaseService.client.storage.from('profile-photos').upload(
            storagePath,
            avatarFile,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
    } else {
      throw ArgumentError('No avatar file or bytes provided');
    }

    return SupabaseService.client.storage.from('profile-photos').getPublicUrl(storagePath);
  }
}
