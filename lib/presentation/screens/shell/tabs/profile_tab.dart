import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/repositories/notification_repository.dart';
import '../../../widgets/widgets.dart';
import '../../admin/admin_dashboard_screen.dart';
import '../../legal/legal_docs.dart';
import '../../notifications/notifications_screen.dart';
import '../../profile/edit_profile_screen.dart';
import '../../support/submit_complaint_screen.dart';

class ProfileTab extends StatelessWidget {
  final UserProfile profile;

  const ProfileTab({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final avatarUrl = profile.avatarUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          FutureBuilder<int>(
            future: NotificationRepository.fetchUnreadCount(profile.id),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'In-App Notifications',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              NotificationsScreen(profile: profile),
                        ),
                      );
                    },
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Admin Panel Access Card (Server Verified)
            if (profile.isAdmin) ...[
              ParkCard(
                showGlowBorder: true,
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Admin Console',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  subtitle: const Text(
                    'Spot Moderation, Complaints, Users, Audit Logs',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.error,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            AdminDashboardScreen(adminProfile: profile),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // User Header Card
            ParkCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: isDark
                        ? AppColors.neonLime
                        : AppColors.accentLight,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Text(
                            profile.fullName.isNotEmpty
                                ? profile.fullName[0].toUpperCase()
                                : 'P',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.midnightNavy
                                  : Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.phone ?? 'No phone added',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? AppColors.neonLime
                                        : AppColors.accentLight)
                                    .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            profile.isAdmin
                                ? 'ADMINISTRATOR'
                                : (profile.accountType == 'host'
                                      ? 'SPOT OWNER'
                                      : 'VEHICLE OWNER'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: profile.isAdmin
                                  ? AppColors.error
                                  : (isDark
                                        ? AppColors.neonLime
                                        : AppColors.accentLight),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Options
            ParkCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Edit Profile & Address'),
                    subtitle: Text(profile.address ?? 'Add address details'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              EditProfileScreen(profile: profile),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('In-App Notifications'),
                    subtitle: const Text('View booking updates & messages'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              NotificationsScreen(profile: profile),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded),
                    title: const Text('Help & Report Issue'),
                    subtitle: const Text(
                      'Submit complaints or payment reports',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              SubmitComplaintScreen(profile: profile),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    subtitle: const Text('Data collection & storage policies'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => LegalDocs.openPrivacyPolicy(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: const Text('Terms of Service'),
                    subtitle: const Text('Platform terms & rules'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => LegalDocs.openTermsOfService(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_outlined,
                      color: AppColors.error,
                    ),
                    title: const Text(
                      'Delete My Account',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Permanently delete account, listings & history',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.error,
                    ),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Your Account?'),
                          content: const Text(
                            'Your profile, NID and vehicle documents, uploaded spot photos, parking listings, and booking history will be permanently deleted. This action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                              child: const Text('Permanently Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await AuthService.deleteAccount();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting account: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sign Out Button
            ParkButton(
              text: 'Sign Out',
              type: ParkButtonType.secondary,
              icon: Icons.logout_rounded,
              onPressed: () async {
                await AuthService.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
