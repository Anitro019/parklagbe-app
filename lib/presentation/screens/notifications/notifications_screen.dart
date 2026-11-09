import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../widgets/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  final UserProfile profile;

  const NotificationsScreen({super.key, required this.profile});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _refreshNotifications();
  }

  void _refreshNotifications() {
    setState(() {
      _notificationsFuture = NotificationRepository.fetchUserNotifications(widget.profile.id);
    });
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await NotificationRepository.markAsRead(notification.id);
      _refreshNotifications();
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await NotificationRepository.markAllAsRead(widget.profile.id);
      _refreshNotifications();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('In-App Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('Mark All Read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshNotifications(),
        child: FutureBuilder<List<AppNotification>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingIndicator(message: 'Loading notifications...');
            }

            final notifications = snapshot.data ?? [];

            if (notifications.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.notifications_none_rounded,
                title: 'No Notifications Yet',
                description: 'You will receive in-app notifications when your booking requests are approved, declined, or updated.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return ParkCard(
                  onTap: () => _markAsRead(item),
                  showGlowBorder: !item.isRead,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (item.isRead
                                  ? (isDark ? AppColors.deepBlue : AppColors.surfaceBorderLight)
                                  : (isDark ? AppColors.neonLime : AppColors.accentLight))
                              .withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.isRead ? Icons.notifications_outlined : Icons.notifications_active_rounded,
                          size: 20,
                          color: item.isRead
                              ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
                              : (isDark ? AppColors.neonLime : AppColors.accentLight),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  DateTimeUtils.formatBdDateTime(item.createdAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.message,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
