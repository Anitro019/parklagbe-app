import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/pdf_receipt_service.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/booking.dart';
import '../../../../data/models/review.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/repositories/booking_repository.dart';
import '../../../../data/repositories/driver_repository.dart';
import '../../../../data/repositories/review_repository.dart';
import '../../../widgets/user_reviews_modal.dart';
import '../../../widgets/widgets.dart';
import '../../driver/submit_review_dialog.dart';

class BookingsTab extends StatefulWidget {
  final UserProfile profile;

  const BookingsTab({super.key, required this.profile});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Booking>> _customerBookingsFuture;
  late Future<List<BookingWithCustomer>> _hostBookingsFuture;

  bool _showHostMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _showHostMode = widget.profile.isHost;
    _refreshBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshBookings() {
    setState(() {
      _customerBookingsFuture = BookingRepository.fetchCustomerBookings(
        widget.profile.id,
      );
      if (widget.profile.isHost) {
        _hostBookingsFuture = BookingRepository.fetchHostBookings(
          widget.profile.id,
        );
      }
    });
  }

  Future<void> _handleCancelBooking(Booking booking) async {
    final now = DateTime.now();
    if (booking.startTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot cancel past or ongoing bookings.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: Text(
          'Are you sure you want to cancel booking ${booking.bookingReference}? The parking slot will be freed up for other renters.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Booking'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await BookingRepository.cancelBooking(booking.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Booking cancelled successfully! Slot is now open for booking.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          _refreshBookings();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cancelling booking: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleApproveBooking(Booking booking) async {
    try {
      await BookingRepository.approveBooking(booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking approved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _refreshBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving booking: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleRejectBooking(Booking booking) async {
    try {
      await BookingRepository.rejectBooking(
        booking.id,
        reason: 'Declined by host',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking request declined.'),
            backgroundColor: AppColors.warning,
          ),
        );
        _refreshBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining booking: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadReceipt(Booking booking) async {
    try {
      final details = await DriverRepository.fetchSpotDetails(booking.spotId);

      await PdfReceiptService.printOrShareReceipt(
        booking: booking,
        spot: details.spot,
        customer: widget.profile,
        owner: details.ownerProfile,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF receipt: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openReviewDialog(
    Booking booking, {
    bool isHostRatingDriver = false,
  }) async {
    final result = await showDialog<Review>(
      context: context,
      builder: (ctx) => SubmitReviewDialog(
        booking: booking,
        isHostRatingDriver: isHostRatingDriver,
      ),
    );
    if (result != null) {
      _refreshBookings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshBookings,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: isDark ? AppColors.neonLime : AppColors.accentLight,
          labelColor: isDark ? AppColors.neonLime : AppColors.accentLight,
          unselectedLabelColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          tabs: const [
            Tab(text: 'Active / Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Host / Renter Mode Selector for Spot Owners
            if (widget.profile.isHost) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        selected: !_showHostMode,
                        label: const Text(
                          'My Rentals (Renter)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onSelected: (_) =>
                            setState(() => _showHostMode = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilterChip(
                        selected: _showHostMode,
                        label: const Text(
                          'Requests for My Spots (Host)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onSelected: (_) => setState(() => _showHostMode = true),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Expanded(
              child: _showHostMode
                  ? _buildHostBookingsView(isDark)
                  : _buildCustomerBookingsView(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerBookingsView(bool isDark) {
    return FutureBuilder<List<Booking>>(
      future: _customerBookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Loading your bookings...');
        }

        final bookings = snapshot.data ?? [];

        final activeList = bookings
            .where(
              (b) =>
                  b.bookingStatus == 'pending' ||
                  b.bookingStatus == 'confirmed' ||
                  b.bookingStatus == 'active',
            )
            .toList();
        final completedList = bookings
            .where((b) => b.bookingStatus == 'completed')
            .toList();
        final cancelledList = bookings
            .where(
              (b) =>
                  b.bookingStatus == 'cancelled' ||
                  b.bookingStatus == 'rejected',
            )
            .toList();

        return TabBarView(
          controller: _tabController,
          children: [
            _buildBookingList(activeList, isDark, isCustomer: true),
            _buildBookingList(completedList, isDark, isCustomer: true),
            _buildBookingList(cancelledList, isDark, isCustomer: true),
          ],
        );
      },
    );
  }

  Widget _buildHostBookingsView(bool isDark) {
    return FutureBuilder<List<BookingWithCustomer>>(
      future: _hostBookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(
            message: 'Loading requests for your spots...',
          );
        }

        final items = snapshot.data ?? [];

        final activeList = items
            .where(
              (b) =>
                  b.booking.bookingStatus == 'pending' ||
                  b.booking.bookingStatus == 'confirmed' ||
                  b.booking.bookingStatus == 'active',
            )
            .toList();
        final completedList = items
            .where((b) => b.booking.bookingStatus == 'completed')
            .toList();
        final cancelledList = items
            .where(
              (b) =>
                  b.booking.bookingStatus == 'cancelled' ||
                  b.booking.bookingStatus == 'rejected',
            )
            .toList();

        return TabBarView(
          controller: _tabController,
          children: [
            _buildHostBookingList(activeList, isDark),
            _buildHostBookingList(completedList, isDark),
            _buildHostBookingList(cancelledList, isDark),
          ],
        );
      },
    );
  }

  Widget _buildBookingList(
    List<Booking> list,
    bool isDark, {
    required bool isCustomer,
  }) {
    if (list.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Bookings Found',
        description: 'No records in this tab.',
        icon: Icons.bookmark_border_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final booking = list[index];
        final canCancel =
            (booking.bookingStatus == 'pending' ||
                booking.bookingStatus == 'confirmed') &&
            booking.startTime.isAfter(DateTime.now());
        final isCompleted = booking.bookingStatus == 'completed';
        final canReview =
            booking.bookingStatus == 'confirmed' ||
            booking.bookingStatus == 'active' ||
            isCompleted;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: ParkCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Ref & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        booking.bookingReference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark
                              ? AppColors.neonLime
                              : AppColors.accentLight,
                        ),
                      ),
                    ),
                    _buildStatusBadge(booking.bookingStatus),
                  ],
                ),
                const SizedBox(height: 10),

                // Booking Date & Time
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Date: ${DateTimeUtils.formatBdDate(booking.bookingDate)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Time: ${DateTimeUtils.formatBdTime(booking.startTime)} - ${DateTimeUtils.formatBdTime(booking.endTime)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Duration: ${booking.durationHours.toStringAsFixed(1)} hrs',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      Formatters.formatCurrency(booking.totalPrice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Actions
                Row(
                  children: [
                    if (canCancel)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Cancel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          onPressed: () => _handleCancelBooking(booking),
                        ),
                      ),
                    if (canCancel && canReview) const SizedBox(width: 8),
                    if (canReview)
                      Expanded(
                        child: _buildReviewButtonOrBadge(
                          booking,
                          isCustomer: true,
                          isDark: isDark,
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.receipt_long_rounded),
                      tooltip: 'Download PDF Receipt',
                      onPressed: () => _downloadReceipt(booking),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHostBookingList(List<BookingWithCustomer> list, bool isDark) {
    if (list.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Booking Requests Found',
        description: 'No requests received in this tab.',
        icon: Icons.garage_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final booking = item.booking;
        final customer = item.customerProfile;
        final isPending = booking.bookingStatus == 'pending';
        final isCompleted = booking.bookingStatus == 'completed';
        final canReview =
            booking.bookingStatus == 'confirmed' ||
            booking.bookingStatus == 'active' ||
            isCompleted;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: ParkCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Driver Profile Info Header with Public Rating Inspection
                if (customer != null) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isDark
                            ? AppColors.neonLime
                            : AppColors.accentLight,
                        child: Text(
                          customer.fullName.isNotEmpty
                              ? customer.fullName[0].toUpperCase()
                              : 'D',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.midnightNavy
                                : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    customer.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (customer.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: AppColors.success,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              booking.vehicleNumber != null
                                  ? 'Plate: ${booking.vehicleNumber}'
                                  : 'Vehicle Owner',
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

                      // Driver Public Rating Badge & Inspector (Feature 3 of Review System)
                      FutureBuilder<RatingSummary>(
                        future: ReviewRepository.fetchUserRatingSummary(
                          customer.id,
                        ),
                        builder: (context, snapshot) {
                          final summary =
                              snapshot.data ??
                              RatingSummary(averageRating: 0, totalReviews: 0);

                          return InkWell(
                            onTap: () =>
                                UserReviewsModal.show(context, customer),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(
                                  alpha: 0.15,
                                ),
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
                                  const SizedBox(width: 4),
                                  Text(
                                    summary.totalReviews > 0
                                        ? '${summary.averageRating.toStringAsFixed(1)} ★'
                                        : 'New Driver',
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
                  ),
                  const Divider(height: 16),
                ],

                // Ref & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        booking.bookingReference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark
                              ? AppColors.neonLime
                              : AppColors.accentLight,
                        ),
                      ),
                    ),
                    _buildStatusBadge(booking.bookingStatus),
                  ],
                ),
                const SizedBox(height: 8),

                Text(
                  'Date: ${DateTimeUtils.formatBdDate(booking.bookingDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Time: ${DateTimeUtils.formatBdTime(booking.startTime)} - ${DateTimeUtils.formatBdTime(booking.endTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Duration: ${booking.durationHours.toStringAsFixed(1)} hrs',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      Formatters.formatCurrency(booking.totalPrice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Host Actions
                Row(
                  children: [
                    if (isPending) ...[
                      Expanded(
                        child: ParkButton(
                          text: 'Approve',
                          type: ParkButtonType.primary,
                          onPressed: () => _handleApproveBooking(booking),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ParkButton(
                          text: 'Decline',
                          type: ParkButtonType.secondary,
                          onPressed: () => _handleRejectBooking(booking),
                        ),
                      ),
                    ] else ...[
                      if (canReview)
                        Expanded(
                          child: _buildReviewButtonOrBadge(
                            booking,
                            isCustomer: false,
                            isDark: isDark,
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.receipt_long_rounded),
                        tooltip: 'PDF Receipt',
                        onPressed: () => _downloadReceipt(booking),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewButtonOrBadge(
    Booking booking, {
    required bool isCustomer,
    required bool isDark,
  }) {
    return FutureBuilder<Review?>(
      future: ReviewRepository.fetchUserReviewForBooking(
        bookingId: booking.id,
        userId: widget.profile.id,
      ),
      builder: (context, snapshot) {
        final existingReview = snapshot.data;

        if (existingReview != null) {
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
                  '${existingReview.rating}',
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

        return Tooltip(
          message: 'Rate & Comment',
          child: ElevatedButton(
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
            onPressed: () =>
                _openReviewDialog(booking, isHostRatingDriver: !isCustomer),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label = status.toUpperCase();

    switch (status) {
      case 'confirmed':
      case 'active':
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
        break;
      case 'completed':
        bg = AppColors.info.withValues(alpha: 0.15);
        fg = AppColors.info;
        break;
      case 'cancelled':
      case 'rejected':
        bg = AppColors.error.withValues(alpha: 0.15);
        fg = AppColors.error;
        break;
      case 'pending':
      default:
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = AppColors.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
