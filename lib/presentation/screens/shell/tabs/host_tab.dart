import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/contact_service.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/booking.dart';
import '../../../../data/models/parking_spot.dart';
import '../../../../data/models/review.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/repositories/booking_repository.dart';
import '../../../../data/repositories/review_repository.dart';
import '../../../../data/repositories/spot_repository.dart';
import '../../../widgets/user_reviews_modal.dart';
import '../../../widgets/widgets.dart';
import '../../host/add_edit_spot_screen.dart';
import '../../driver/submit_review_dialog.dart';

class HostTab extends StatefulWidget {
  final UserProfile profile;

  const HostTab({super.key, required this.profile});

  @override
  State<HostTab> createState() => _HostTabState();
}

class _HostTabState extends State<HostTab> {
  late Future<List<ParkingSpot>> _spotsFuture;
  late Future<OwnerDashboardStats> _statsFuture;
  late Future<List<BookingWithCustomer>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _spotsFuture = SpotRepository.fetchOwnerSpots(widget.profile.id);
      _statsFuture = SpotRepository.fetchOwnerDashboardStats(widget.profile.id);
      _bookingsFuture = BookingRepository.fetchHostBookings(widget.profile.id);
    });
  }

  Future<void> _openAddSpot() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddEditSpotScreen(ownerId: widget.profile.id),
      ),
    );
    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _openEditSpot(ParkingSpot spot) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            AddEditSpotScreen(ownerId: widget.profile.id, spot: spot),
      ),
    );
    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _handleApproveBooking(BookingWithCustomer item) async {
    try {
      await BookingRepository.approveBooking(item.booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booking ${item.booking.bookingReference} approved successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception:', '').trim();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Booking Conflict Error'),
            content: Text(
              'Cannot approve request:\n$errorMsg\n\nAnother booking already occupies this slot or spot capacity is full.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleRejectBooking(BookingWithCustomer item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Booking Request?'),
        content: Text(
          'Are you sure you want to decline request ${item.booking.bookingReference}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Decline Request'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await BookingRepository.rejectBooking(item.booking.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking request declined.'),
              backgroundColor: AppColors.warning,
            ),
          );
          _refreshData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleCompleteBooking(BookingWithCustomer item) async {
    try {
      await BookingRepository.completeBooking(item.booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booking ${item.booking.bookingReference} marked as completed.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openReviewDialog(Booking booking) async {
    final result = await showDialog<Review>(
      context: context,
      builder: (context) =>
          SubmitReviewDialog(booking: booking, isHostRatingDriver: true),
    );
    if (result != null) {
      _refreshData();
    }
  }

  Future<void> _handleDeleteSpot(ParkingSpot spot) async {
    try {
      final canDelete = await SpotRepository.canDeleteSpot(spot.id);

      if (!canDelete) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cannot Delete Listing'),
            content: Text(
              'Listing "${spot.title}" has active or upcoming bookings.\n\nTo prevent disruption for drivers, you cannot delete this listing right now.\n\nSafe Alternative: Toggle off the listing\'s active status ("Temporarily Unavailable") to prevent new bookings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Listing?'),
          content: Text(
            'Are you sure you want to permanently delete "${spot.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await SpotRepository.deleteSpot(spot.id, widget.profile.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Listing deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _refreshData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Dashboard',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSpot,
        backgroundColor: isDark ? AppColors.neonLime : AppColors.accentLight,
        foregroundColor: isDark ? AppColors.midnightNavy : Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text(
          'Add Spot',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dashboard Stats Grid
              FutureBuilder<OwnerDashboardStats>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  final stats = snapshot.data;

                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.8,
                    children: [
                      _buildStatCard(
                        'Total Listings',
                        '${stats?.totalListings ?? 0}',
                        Icons.garage_outlined,
                        isDark,
                      ),
                      _buildStatCard(
                        'Approved',
                        '${stats?.approvedListings ?? 0}',
                        Icons.verified_outlined,
                        isDark,
                        color: AppColors.success,
                      ),
                      _buildStatCard(
                        'Pending Approval',
                        '${stats?.pendingListings ?? 0}',
                        Icons.hourglass_top_outlined,
                        isDark,
                        color: AppColors.warning,
                      ),
                      _buildStatCard(
                        'Booking Requests',
                        '${stats?.pendingBookings ?? 0}',
                        Icons.confirmation_number_outlined,
                        isDark,
                        color: isDark ? AppColors.neonCyan : AppColors.info,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Booking Requests for Host Spots
              Text(
                'Renter Booking Requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),

              FutureBuilder<List<BookingWithCustomer>>(
                future: _bookingsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingIndicator(
                      message: 'Loading booking requests...',
                    );
                  }

                  final requests = snapshot.data ?? [];

                  if (requests.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.confirmation_number_outlined,
                      title: 'No Booking Requests',
                      description: 'When drivers request to book your parking spots, their details and requests will appear here.',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: requests.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = requests[index];
                      return _buildHostBookingCard(item, isDark);
                    },
                  );
                },
              ),
              const SizedBox(height: 24),

              // Listings Section Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'My Parking Listings',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _openAddSpot,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'New Spot',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Real Parking Spots List
              FutureBuilder<List<ParkingSpot>>(
                future: _spotsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: LoadingIndicator(
                        message: 'Fetching your parking listings...',
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return ParkCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load listings: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ParkButton(
                            text: 'Retry',
                            type: ParkButtonType.secondary,
                            onPressed: _refreshData,
                          ),
                        ],
                      ),
                    );
                  }

                  final spots = snapshot.data ?? [];

                  if (spots.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.garage_outlined,
                      title: 'No Parking Listings Yet',
                      description: 'List your garage, driveway, or vacant space to start earning daily or hourly income in Bangladesh.',
                      actionText: 'List Your Parking Spot',
                      onAction: _openAddSpot,
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: spots.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final spot = spots[index];
                      return _buildSpotCard(spot, isDark);
                    },
                  );
                },
              ),
              const SizedBox(height: 80), // FAB spacing
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHostBookingCard(BookingWithCustomer item, bool isDark) {
    final b = item.booking;
    final c = item.customerProfile;

    Color statusColor;
    switch (b.bookingStatus) {
      case 'confirmed':
      case 'active':
        statusColor = AppColors.success;
        break;
      case 'completed':
        statusColor = isDark ? AppColors.neonCyan : AppColors.info;
        break;
      case 'rejected':
      case 'cancelled':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.warning;
    }

    final custPhone = c?.phone;
    final hasCustomerPhone = custPhone != null && custPhone.isNotEmpty;

    return ParkCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Ref: ${b.bookingReference}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  b.bookingStatus.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (c != null)
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: isDark
                      ? AppColors.neonLime
                      : AppColors.accentLight,
                  child: Text(
                    c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : 'D',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.midnightNavy : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Renter: ${c.fullName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (hasCustomerPhone)
                        Text(
                          custPhone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                    ],
                  ),
                ),
                FutureBuilder<RatingSummary>(
                  future: ReviewRepository.fetchUserRatingSummary(c.id),
                  builder: (context, snapshot) {
                    final summary =
                        snapshot.data ??
                        RatingSummary(averageRating: 0, totalReviews: 0);

                    return InkWell(
                      onTap: () => UserReviewsModal.show(context, c),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.warning),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              summary.totalReviews > 0
                                  ? summary.averageRating.toStringAsFixed(1)
                                  : 'New',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          else
            Text(
              'Renter: Driver ${hasCustomerPhone ? "($custPhone)" : ""}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          const SizedBox(height: 4),
          Text(
            'Time: ${DateTimeUtils.formatBdDate(b.bookingDate)} (${DateTimeUtils.formatBdTime(b.startTime)} - ${DateTimeUtils.formatBdTime(b.endTime)})',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Vehicle: ${b.vehicleType.toUpperCase()} ${b.vehicleNumber != null ? "• ${b.vehicleNumber}" : ""} • Total: ${Formatters.formatCurrency(b.totalPrice)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.neonLime : AppColors.accentLight,
            ),
          ),
          if (hasCustomerPhone) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.phone_outlined,
                    size: 20,
                    color: AppColors.success,
                  ),
                  tooltip: 'Call Renter',
                  onPressed: () => ContactService.makePhoneCall(custPhone),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chat_outlined,
                    size: 20,
                    color: AppColors.success,
                  ),
                  tooltip: 'WhatsApp Renter',
                  onPressed: () => ContactService.openWhatsApp(custPhone),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),

          // Actions for pending/confirmed requests
          if (b.bookingStatus == 'pending') ...[
            Row(
              children: [
                Expanded(
                  child: ParkButton(
                    text: 'Approve',
                    onPressed: () => _handleApproveBooking(item),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ParkButton(
                    text: 'Decline',
                    type: ParkButtonType.secondary,
                    onPressed: () => _handleRejectBooking(item),
                  ),
                ),
              ],
            ),
          ] else if (b.bookingStatus == 'confirmed' ||
              b.bookingStatus == 'active' ||
              b.bookingStatus == 'completed') ...[
            Row(
              children: [
                if (b.bookingStatus == 'confirmed' ||
                    b.bookingStatus == 'active') ...[
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _handleCompleteBooking(item),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: AppColors.success,
                      ),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Mark Completed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(child: _buildReviewButtonOrBadge(b, isDark)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewButtonOrBadge(Booking booking, bool isDark) {
    return FutureBuilder<Review?>(
      future: ReviewRepository.fetchUserReviewForBooking(
        bookingId: booking.id,
        userId: widget.profile.id,
      ),
      builder: (context, snapshot) {
        final review = snapshot.data;
        if (review != null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 3),
                Text(
                  '${review.rating}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          );
        }

        return ElevatedButton(
          onPressed: () => _openReviewDialog(booking),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: isDark
                ? AppColors.neonLime
                : AppColors.accentLight,
            foregroundColor: isDark ? AppColors.midnightNavy : Colors.white,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: const Text(
            'Feedback',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    bool isDark, {
    Color? color,
  }) {
    return ParkCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color:
                        color ??
                        (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight),
                  ),
                ),
              ),
              Icon(
                icon,
                size: 22,
                color:
                    color ??
                    (isDark ? AppColors.neonLime : AppColors.accentLight),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotCard(ParkingSpot spot, bool isDark) {
    Color statusColor;
    String statusText;

    if (!spot.isActive) {
      statusColor = AppColors.textMutedDark;
      statusText = 'UNAVAILABLE';
    } else if (spot.approvalStatus == 'approved') {
      statusColor = AppColors.success;
      statusText = 'APPROVED';
    } else if (spot.approvalStatus == 'rejected') {
      statusColor = AppColors.error;
      statusText = 'REJECTED';
    } else {
      statusColor = AppColors.warning;
      statusText = 'PENDING APPROVAL';
    }

    String priceText = '';
    if (spot.hourlyPrice != null && spot.hourlyPrice! > 0) {
      priceText = '${Formatters.formatCurrency(spot.hourlyPrice!)} / hr';
    } else if (spot.dailyPrice != null && spot.dailyPrice! > 0) {
      priceText = '${Formatters.formatCurrency(spot.dailyPrice!)} / day';
    } else if (spot.monthlyPrice != null && spot.monthlyPrice! > 0) {
      priceText = '${Formatters.formatCurrency(spot.monthlyPrice!)} / month';
    }

    return ParkCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  spot.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Area & Price
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 15,
                color: isDark ? AppColors.neonLime : AppColors.accentLight,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${spot.area}, ${spot.district}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              if (priceText.isNotEmpty)
                Text(
                  priceText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.neonLime : AppColors.accentLight,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 15,
                color: isDark ? AppColors.neonLime : AppColors.accentLight,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  DateTimeUtils.formatAvailabilitySchedule(
                    availableFrom: spot.effectiveAvailableFrom,
                    availableTo: spot.effectiveAvailableTo,
                    availableHoursStart: spot.availableHoursStart,
                    availableHoursEnd: spot.availableHoursEnd,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Active Switch & Action Buttons
          Row(
            children: [
              Text(
                'Available:',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              Switch(
                value: spot.isActive,
                activeTrackColor: isDark
                    ? AppColors.neonLime
                    : AppColors.accentLight,
                activeThumbColor: isDark
                    ? AppColors.midnightNavy
                    : Colors.white,
                onChanged: (val) async {
                  await SpotRepository.toggleSpotActiveStatus(
                    spot.id,
                    widget.profile.id,
                    val,
                  );
                  _refreshData();
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit Spot',
                onPressed: () => _openEditSpot(spot),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.error,
                ),
                tooltip: 'Delete Spot',
                onPressed: () => _handleDeleteSpot(spot),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
