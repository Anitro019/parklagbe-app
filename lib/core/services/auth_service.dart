import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/user_profile.dart';
import 'supabase_service.dart';

class AuthService {
  static bool _accountDeletionCompleted = false;

  static String get _emailRedirectUrl =>
      kIsWeb ? Uri.base.origin : 'parklagbee://login-callback';

  /// Get current auth session
  static Session? get currentSession {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) {
      return null;
    }
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
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) {
      return null;
    }
    return SupabaseService.client.auth.currentUser;
  }

  /// Current user email verified status
  static bool get isEmailVerified {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) {
      return false;
    }
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
      throw StateError(
        'Please configure real Supabase credentials before registering accounts. Pass --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
      );
    }

    final String cleanAccountType = accountType.trim().toLowerCase();
    final String safeRole =
        (cleanAccountType == 'host' ||
            cleanAccountType == 'spot_owner' ||
            cleanAccountType == 'owner')
        ? 'host'
        : 'driver';

    final response = await SupabaseService.client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: _emailRedirectUrl,
      data: {
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
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

      // Prevent automatic session creation until email confirmation link is clicked
      if (response.session != null && (user.emailConfirmedAt == null)) {
        await SupabaseService.client.auth.signOut();
      }
    }

    return response;
  }

  /// Resend Signup Verification Email
  static Future<void> resendVerificationEmail(String email) async {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) {
      return;
    }
    try {
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: _emailRedirectUrl,
      );
    } on AuthRetryableFetchException catch (e) {
      debugPrint(
        'AuthRetryableFetchException during resendVerificationEmail: $e',
      );
      throw Exception(
        'Network error connecting to auth server. Please check internet connection.',
      );
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
      throw StateError(
        'Please configure real Supabase credentials before signing in.',
      );
    }

    try {
      return await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthRetryableFetchException catch (e) {
      debugPrint('AuthRetryableFetchException during signInWithEmail: $e');
      throw Exception(
        'Network error connecting to auth server. Please check internet connection.',
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Initiate Password Reset Email
  static Future<void> sendPasswordResetEmail(
    String email, {
    String? redirectTo,
  }) async {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) {
      throw StateError(
        'Please configure real Supabase credentials before resetting password.',
      );
    }

    final effectiveRedirectTo =
        redirectTo ??
        (kIsWeb ? '${Uri.base.origin}/#/auth' : 'parklagbee://reset-password');

    try {
      await SupabaseService.client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: effectiveRedirectTo,
      );
    } on AuthRetryableFetchException catch (e) {
      debugPrint(
        'AuthRetryableFetchException during sendPasswordResetEmail: $e',
      );
      throw Exception(
        'Network error connecting to auth server. Please check internet connection.',
      );
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

    final userId = currentUser?.id;
    if (userId == null) throw StateError('Not logged in');

    await _deleteUserStorage(userId);
    await SupabaseService.client.rpc('delete_user_account');
    _accountDeletionCompleted = true;
    await SupabaseService.client.auth.signOut(scope: SignOutScope.local);
  }

  static bool consumeAccountDeletionCompleted() {
    final completed = _accountDeletionCompleted;
    _accountDeletionCompleted = false;
    return completed;
  }

  static Future<void> _deleteUserStorage(String userId) async {
    final client = SupabaseService.client;
    final spotRows = await client
        .from('parking_spots')
        .select('id')
        .eq('owner_id', userId);
    final spotIds = (spotRows as List)
        .map((row) => row['id'] as String)
        .toList();

    final pathsByBucket = <String, Set<String>>{
      'verification_docs': {},
      'profile-photos': {},
      'parking-photos': {},
      'spot_images': {},
    };

    final profile = await client
        .from('profiles')
        .select('verification_doc_url, avatar_url')
        .eq('id', userId)
        .maybeSingle();
    if (profile != null) {
      _addStorageUrl(pathsByBucket, profile['verification_doc_url'] as String?);
      _addStorageUrl(pathsByBucket, profile['avatar_url'] as String?);
    }

    if (spotIds.isNotEmpty) {
      final photoRows = await client
          .from('parking_photos')
          .select('storage_path')
          .inFilter('spot_id', spotIds);
      for (final row in photoRows as List) {
        _addStorageUrl(pathsByBucket, row['storage_path'] as String?);
      }
    }

    await _collectFolderFiles('verification_docs', userId, pathsByBucket);
    await _collectFolderFiles('profile-photos', userId, pathsByBucket);
    await _collectFolderFiles(
      'spot_images',
      userId,
      pathsByBucket,
      ignoreMissingBucket: true,
    );
    for (final spotId in spotIds) {
      await _collectFolderFiles('parking-photos', spotId, pathsByBucket);
      await _collectFolderFiles(
        'spot_images',
        spotId,
        pathsByBucket,
        ignoreMissingBucket: true,
      );
    }

    for (final entry in pathsByBucket.entries) {
      if (entry.value.isNotEmpty) {
        final paths = entry.value.toList();
        for (var start = 0; start < paths.length; start += 100) {
          final end = (start + 100 < paths.length) ? start + 100 : paths.length;
          await client.storage
              .from(entry.key)
              .remove(paths.sublist(start, end));
        }
      }
    }
  }

  static Future<void> _collectFolderFiles(
    String bucket,
    String folder,
    Map<String, Set<String>> pathsByBucket, {
    bool ignoreMissingBucket = false,
  }) async {
    try {
      const pageSize = 1000;
      var offset = 0;
      while (true) {
        final files = await SupabaseService.client.storage
            .from(bucket)
            .list(
              path: folder,
              searchOptions: SearchOptions(limit: pageSize, offset: offset),
            );
        pathsByBucket[bucket]!.addAll(
          files
              .where((file) => file.id != null)
              .map((file) => '$folder/${file.name}'),
        );
        if (files.length < pageSize) break;
        offset += files.length;
      }
    } on StorageException catch (error) {
      if (!ignoreMissingBucket ||
          !error.message.toLowerCase().contains('bucket not found')) {
        rethrow;
      }
    }
  }

  static void _addStorageUrl(
    Map<String, Set<String>> pathsByBucket,
    String? rawUrl,
  ) {
    if (rawUrl == null || rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    final segments = uri.pathSegments;
    final publicIndex = segments.indexOf('public');
    if (publicIndex < 0 || publicIndex + 2 >= segments.length) return;
    final bucket = segments[publicIndex + 1];
    final objectPath = segments.skip(publicIndex + 2).join('/');
    pathsByBucket[bucket]?.add(objectPath);
  }

  /// Sign Out
  static Future<void> signOut() async {
    if (SupabaseService.isInitialized && !SupabaseService.isPlaceholderConfig) {
      await SupabaseService.client.auth.signOut();
    }
  }

  /// Fetch User Profile
  static Future<UserProfile?> fetchUserProfile() async {
    if (!SupabaseService.isInitialized || SupabaseService.isPlaceholderConfig) {
      return null;
    }

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

  /// Update User Profile Details with Identity Verification Document Support
  static Future<void> updateUserProfile({
    required String fullName,
    required String phone,
    required String address,
    String? nidNumber,
    String? drivingLicenseNumber,
    File? avatarFile,
    Uint8List? avatarBytes,
    File? docFile,
    Uint8List? docBytes,
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

    String? docUrl;
    if (docFile != null || docBytes != null) {
      docUrl = await _uploadVerificationDoc(
        userId: user.id,
        docFile: docFile,
        docBytes: docBytes,
      );
    }

    final updates = <String, dynamic>{
      'id': user.id,
      'full_name': fullName,
      'phone': phone,
      'address': address,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (nidNumber != null && nidNumber.trim().isNotEmpty) {
      updates['nid_number'] = nidNumber.trim();
    }
    if (drivingLicenseNumber != null && drivingLicenseNumber.trim().isNotEmpty) {
      updates['driving_license_number'] = drivingLicenseNumber.trim();
    }
    if (docUrl != null) {
      updates['verification_doc_url'] = docUrl;
      updates['is_verified'] =
          true; // Mark account verified upon submitting valid document
    }

    await SupabaseService.client.from('profiles').upsert(updates);
  }

  /// Upload verification document to private verification_docs bucket
  static Future<String> _uploadVerificationDoc({
    required String userId,
    File? docFile,
    Uint8List? docBytes,
  }) async {
    final storagePath =
        '$userId/verification_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (kIsWeb && docBytes != null) {
      await SupabaseService.client.storage
          .from('verification_docs')
          .uploadBinary(
            storagePath,
            docBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    } else if (docFile != null) {
      await SupabaseService.client.storage
          .from('verification_docs')
          .upload(
            storagePath,
            docFile,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    } else {
      throw ArgumentError('No document file or bytes provided');
    }

    return SupabaseService.client.storage
        .from('verification_docs')
        .getPublicUrl(storagePath);
  }

  /// Private helper to upload avatar to profile-photos bucket
  static Future<String> _uploadAvatar({
    required String userId,
    File? avatarFile,
    Uint8List? avatarBytes,
  }) async {
    final storagePath =
        '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (kIsWeb && avatarBytes != null) {
      await SupabaseService.client.storage
          .from('profile-photos')
          .uploadBinary(
            storagePath,
            avatarBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    } else if (avatarFile != null) {
      await SupabaseService.client.storage
          .from('profile-photos')
          .upload(
            storagePath,
            avatarFile,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    } else {
      throw ArgumentError('No avatar file or bytes provided');
    }

    return SupabaseService.client.storage
        .from('profile-photos')
        .getPublicUrl(storagePath);
  }
}
