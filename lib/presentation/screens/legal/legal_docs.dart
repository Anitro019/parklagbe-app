import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_urls.dart';

class LegalDocs {
  /// Launch external Privacy Policy web link
  static Future<void> openPrivacyPolicy(BuildContext context) async {
    final opened = await openExternalUrl(AppUrls.privacyPolicyUrl);
    if (!opened && context.mounted) showPrivacyPolicyDialog(context);
  }

  /// Launch external Terms of Service web link
  static Future<void> openTermsOfService(BuildContext context) async {
    final opened = await openExternalUrl(AppUrls.termsOfServiceUrl);
    if (!opened && context.mounted) showTermsDialog(context);
  }

  static Future<bool> openExternalUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || (!uri.isScheme('https') && !uri.isScheme('http'))) {
      return false;
    }

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// In-App Privacy Policy Dialog
  static void showPrivacyPolicyDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.deepBlue : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: AppColors.success),
            SizedBox(width: 8),
            Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ParkLagbee Privacy Policy',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? AppColors.neonLime : AppColors.accentLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Data Collection: We collect full name, phone number, address, vehicle details, and parking spot imagery to facilitate parking rental services in Bangladesh.\n\n'
                '2. Account Deletion: In compliance with Google Play Store rules, you can permanently delete your account, personal data, listings, and history at any time from your Profile Settings.\n\n'
                '3. Security & Storage: All identity verification documents (NID, Driving License) are stored securely in encrypted private buckets.\n\n'
                '4. Location & Contact Info: Contact information is shared only between confirmed renters and hosts for offline payment/gate pass discussions.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// In-App Terms of Service Dialog
  static void showTermsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.deepBlue : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gavel_outlined, color: AppColors.warning),
            SizedBox(width: 8),
            Text(
              'Terms of Service',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ParkLagbee Terms & Conditions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? AppColors.neonLime : AppColors.accentLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Platform Role: ParkLagbee connects parking space owners (Hosts) with vehicle drivers (Renters). ParkLagbee does not hold or process advance payments directly.\n\n'
                '2. Booking Commitments: Renters must adhere to selected booking start & end times. Overstaying without host approval is strictly prohibited.\n\n'
                '3. Cancellation Policy: Renters can cancel pending or upcoming bookings before the start time without penalty.\n\n'
                '4. Dispute Resolution: Both renters and hosts can submit reports and access helpline call/WhatsApp support for dispute resolution.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
