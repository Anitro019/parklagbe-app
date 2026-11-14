import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/datetime_utils.dart';
import '../../data/models/review.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/review_repository.dart';
import 'widgets.dart';

class UserReviewsModal extends StatelessWidget {
  final UserProfile targetUser;

  const UserReviewsModal({super.key, required this.targetUser});

  static Future<void> show(BuildContext context, UserProfile user) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.deepBlue
          : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: UserReviewsModal(targetUser: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header User Info & Verified Badge
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark
                    ? AppColors.neonLime
                    : AppColors.accentLight,
                child: Text(
                  targetUser.fullName.isNotEmpty
                      ? targetUser.fullName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.midnightNavy : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            targetUser.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (targetUser.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: AppColors.success,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      targetUser.isDriver
                          ? 'Vehicle Owner / Driver'
                          : 'Spot Owner / Host',
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
            ],
          ),
          const SizedBox(height: 16),

          FutureBuilder<RatingSummary>(
            future: ReviewRepository.fetchUserRatingSummary(targetUser.id),
            builder: (context, snapshot) {
              final summary =
                  snapshot.data ??
                  RatingSummary(averageRating: 0, totalReviews: 0);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.neonLime : AppColors.accentLight)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.warning,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      summary.totalReviews > 0
                          ? '${summary.averageRating.toStringAsFixed(1)} ★ (${summary.totalReviews} ${summary.totalReviews == 1 ? "review" : "reviews"})'
                          : 'New User (No ratings yet)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Reviews List
          Expanded(
            child: FutureBuilder<List<Review>>(
              future: ReviewRepository.fetchUserReceivedReviews(targetUser.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(message: 'Loading reviews...');
                }

                final reviews = snapshot.data ?? [];

                if (reviews.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.rate_review_outlined,
                    title: 'No Reviews Recorded',
                    description:
                        'No public reviews have been left for this user yet.',
                  );
                }

                return ListView.separated(
                  itemCount: reviews.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = reviews[index];
                    return ParkCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.reviewerName ?? 'ParkLagbee User',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: AppColors.warning,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${item.rating}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (item.reviewText != null &&
                              item.reviewText!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.reviewText!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            DateTimeUtils.formatBdDateTime(item.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMutedLight,
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
        ],
      ),
    );
  }
}
