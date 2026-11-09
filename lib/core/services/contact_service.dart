import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactService {
  /// Launch direct phone dialer
  static Future<bool> makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return false;

    final uri = Uri.parse('tel:$cleanPhone');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching phone call: $e');
      return false;
    }
  }

  /// Launch WhatsApp chat using validated wa.me link
  static Future<bool> openWhatsApp(String phoneNumber, {String? customMessage}) async {
    // Sanitize phone number (remove +, spaces, hyphens)
    String cleanDigits = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // Default Bangladesh country code +88 if missing
    if (cleanDigits.startsWith('01') && cleanDigits.length == 11) {
      cleanDigits = '88$cleanDigits';
    }

    if (cleanDigits.isEmpty) return false;

    final message = customMessage ?? 'Hello! Regarding ParkLagbee parking booking.';
    final encodedMsg = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$cleanDigits?text=$encodedMsg');

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      return false;
    }
  }
}
