import 'package:flutter_test/flutter_test.dart';
import 'package:parklagbee/core/services/supabase_service.dart';

void main() {
  group('SupabaseService URL Sanitization Tests', () {
    test('Removes trailing slashes from Supabase URL', () {
      const rawUrl = 'https://xyzproject.supabase.co///';
      final cleanUrl = SupabaseService.sanitizeUrl(rawUrl);
      expect(cleanUrl, equals('https://xyzproject.supabase.co'));
    });

    test('Removes whitespace and trailing /auth/v1 path if mistakenly added', () {
      const rawUrl = '  https://xyzproject.supabase.co/auth/v1/ ';
      final cleanUrl = SupabaseService.sanitizeUrl(rawUrl);
      expect(cleanUrl, equals('https://xyzproject.supabase.co'));
    });

    test('Leaves clean Supabase URL unchanged', () {
      const rawUrl = 'https://xyzproject.supabase.co';
      final cleanUrl = SupabaseService.sanitizeUrl(rawUrl);
      expect(cleanUrl, equals('https://xyzproject.supabase.co'));
    });
  });
}
