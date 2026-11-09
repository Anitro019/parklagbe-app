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
import '../../../widgets/widgets.dart';
import '../../driver/submit_review_dialog.dart';

class BookingsTab extends StatefulWidget {
  final UserProfile profile;

  const BookingsTab({super.key, required this.profile});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  late Future<List<Booking>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _refreshBookings();
  }

  void _refreshBookings() {
    setState(() {
      _bookingsFuture = BookingRepository.fetchCustomerBookings(widget.profile.id);
    });
  }

  Future<void> _handleCancelBooking(Booking booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: Text('Are you sure you want to cancel booking ${booking.bookingReference}?'),
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
              content: Text('Booking cancelled successfully'),
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
            tooltip: 'Refresh Bookings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshBookings(),
        child: FutureBuilder<List<Booking>>(
          future: _bookingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingIndicator(message: 'Loading your bookings...');
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Error loading bookings: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ParkButton(
                      text: 'Retry',
                      type: ParkButtonType.secondary,
                      onPressed: _refreshBookings,
                    ),
                  ],
                ),
              );
            }

            final bookings = snapshot.data ?? [];

            if (bookings.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.confirmation_number_outlined,
                title: 'No Active Bookings',
                description: 'You haven\'t booked any parking spot yet. Search for a spot on the Home tab to make your first booking.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final booking = bookings[index];
                return _buildBookingCard(booking, isDark);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, bool isDark) {
    Color statusColor;
    switch (booking.bookingStatus) {
      case 'confirmed':
      case 'active':
        statusColor = AppColors.success;
        break;
      case 'completed':
        statusColor = isDark ? AppColors.neonCyan : AppColors.info;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.warning; // 'pending'
    }

    final canCancel = booking.bookingStatus == 'pending' || booking.bookingStatus == 'confirmed';
    final isCompleted = booking.bookingStatus == 'completed';

    return ParkCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reference & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                booking.bookingReference,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  booking.bookingStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Date & Time
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? AppColors.neonLime : AppColors.accentLight),
              const SizedBox(width: 6),
              Text(
                DateTimeUtils.formatBdDate(booking.bookingDate),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              Icon(Icons.access_time_rounded, size: 14, color: isDark ? AppColors.neonLime : AppColors.accentLight),
              const SizedBox(width: 6),
              Text(
                '${DateTimeUtils.formatBdTime(booking.startTime)} - ${DateTimeUtils.formatBdTime(booking.endTime)}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Price & Vehicle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vehicle: ${booking.vehicleType.toUpperCase()} ${booking.vehicleNumber != null ? "(${booking.vehicleNumber})" : ""}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              Text(
                'Total: ${Formatters.formatCurrency(booking.totalPrice)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.neonLime : AppColors.accentLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _downloadReceipt(booking),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('PDF Receipt', style: TextStyle(fontSize: 12)),
              ),
              if (isCompleted)
                TextButton.icon(
                  onPressed: () async {
                    final dialogCtx = context;
                    final result = await showDialog<Review>(
                      context: dialogCtx,
                      builder: (context) => SubmitReviewDialog(booking: booking),
                    );
                    if (result != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Review submitted successfully! Thank you.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.star_outline_rounded, size: 16, color: AppColors.warning),
                  label: const Text('Write Review', style: TextStyle(color: AppColors.warning, fontSize: 12)),
                )
              else if (canCancel)
                TextButton.icon(
                  onPressed: () => _handleCancelBooking(booking),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                  label: const Text('Cancel', style: TextStyle(color: AppColors.error, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
