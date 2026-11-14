import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Configurable Supabase credentials.
  static const String _defaultUrl = 'https://nfjejfnmugdhaorobvhd.supabase.co';
  static const String _defaultPublishableKey = 'sb_publishable_ChWgLal6M-V3AKePOJVZJg_QVBl5QFl';

  static String get supabaseUrl => sanitizeUrl(
        const String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultUrl),
      );

  static String get supabaseAnonKey =>
      const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: _defaultPublishableKey).trim();

  /// Check if Supabase credentials are placeholder defaults
  static bool get isPlaceholderConfig =>
      supabaseUrl.contains('your-supabase-project') ||
      supabaseAnonKey.contains('your-actual-anon-key');

  /// Sanitizes raw Supabase project URL by trimming whitespace, trailing slashes, and redundant path prefixes
  static String sanitizeUrl(String rawUrl) {
    String clean = rawUrl.trim();
    // Remove trailing slashes
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    // Remove mistakenly appended endpoints
    if (clean.endsWith('/auth/v1')) {
      clean = clean.substring(0, clean.length - '/auth/v1'.length);
    }
    if (clean.endsWith('/rest/v1')) {
      clean = clean.substring(0, clean.length - '/rest/v1'.length);
    }
    return clean;
  }

  /// Check if Supabase client is initialized
  static bool get isInitialized {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  /// Initializes Supabase Flutter SDK with PKCE flow for deep linking
  static Future<void> initialize({String? url, String? publishableKey}) async {
    final rawUrl = url ?? supabaseUrl;
    final cleanUrl = sanitizeUrl(rawUrl);
    final cleanKey = (publishableKey ?? supabaseAnonKey).trim();

    if (cleanUrl.contains('your-supabase-project')) {
      debugPrint('Supabase initialized with placeholder URL. Provide real credentials via --dart-define=SUPABASE_URL=...');
    }

    await Supabase.initialize(
      url: cleanUrl,
      publishableKey: cleanKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      debug: kDebugMode,
    );
  }

  /// Get active Supabase client instance safely
  static SupabaseClient get client {
    if (!isInitialized) {
      throw StateError('Supabase client is not initialized yet.');
    }
    return Supabase.instance.client;
  }

  /// Quick accessor for current authenticated user
  static User? get currentUser => (isInitialized && !isPlaceholderConfig) ? client.auth.currentUser : null;

  /// Check if user is logged in
  static bool get isAuthenticated => currentUser != null;
}
