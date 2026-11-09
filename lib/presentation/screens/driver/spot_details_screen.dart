import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/parking_photo.dart';
import '../../../data/models/parking_spot.dart';
import '../../../data/models/review.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../widgets/widgets.dart';
import 'booking_dialog.dart';

class SpotDetailsScreen extends StatefulWidget {
  final ParkingSpot spot;

  const SpotDetailsScreen({super.key, required this.spot});

  @override
  State<SpotDetailsScreen> createState() => _SpotDetailsScreenState();
}

class _SpotDetailsScreenState extends State<SpotDetailsScreen> {
  late Future<List<ParkingPhoto>> _photosFuture;
  late Future<List<Review>> _reviewsFuture;
  late Future<SpotWithOwner> _detailsFuture;

  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _photosFuture = DriverRepository.fetchSpotPhotos(widget.spot.id);
    _reviewsFuture = DriverRepository.fetchSpotReviews(widget.spot.id);
    _detailsFuture = DriverRepository.fetchSpotDetails(widget.spot.id);

    // Save to local recently viewed history
    DriverRepository.saveRecentlyViewedSpot(widget.spot.id);
  }

  Future<void> _openGoogleMaps(String? mapsUrl) async {
    if (mapsUrl == null || mapsUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Maps URL was not provided for this listing.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final uri = Uri.tryParse(mapsUrl.trim());
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Google Maps link format.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch Google Maps on this device.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spot = widget.spot;

    return Scaffold(
      appBar: AppBar(
        title: Text(spot.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Photo Carousel
            FutureBuilder<List<ParkingPhoto>>(
              future: _photosFuture,
              builder: (context, snapshot) {
                final photos = snapshot.data ?? [];

                if (photos.isEmpty) {
                  return Container(
                    height: 220,
                    color: isDark ? AppColors.deepBlue : AppColors.surfaceBorderLight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_parking_rounded,
                          size: 64,
                          color: isDark ? AppColors.neonLime : AppColors.accentLight,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No photos uploaded for this listing',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SizedBox(
                  height: 240,
                  child: Stack(
                    children: [
                      PageView.builder(
                        itemCount: photos.length,
                        onPageChanged: (idx) {
                          setState(() => _currentPhotoIndex = idx);
                        },
                        itemBuilder: (context, index) {
                          return Image.network(
                            photos[index].storagePath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          );
                        },
                      ),
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            photos.length,
                            (idx) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _currentPhotoIndex == idx ? 16 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentPhotoIndex == idx
                                    ? (isDark ? AppColors.neonLime : AppColors.accentLight)
                                    : Colors.white54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Approved Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          spot.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.success),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified, size: 12, color: AppColors.success),
                            SizedBox(width: 4),
                            Text(
                              'VERIFIED',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Area & Address
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: isDark ? AppColors.neonLime : AppColors.accentLight),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${spot.address}, ${spot.area}, ${spot.district}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Open in Google Maps Action Button
                  ParkButton(
                    text: 'Open in Google Maps',
                    type: ParkButtonType.secondary,
                    icon: Icons.map_outlined,
                    onPressed: () => _openGoogleMaps(spot.googleMapsUrl),
                  ),
                  const SizedBox(height: 20),

                  // Rates Grid
                  ParkCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rental Rates',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.neonLime : AppColors.accentLight,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            if (spot.hourlyPrice != null)
                              _buildRateTile('Hourly Rate', Formatters.formatCurrency(spot.hourlyPrice!), isDark),
                            if (spot.dailyPrice != null)
                              _buildRateTile('Daily Rate', Formatters.formatCurrency(spot.dailyPrice!), isDark),
                            if (spot.monthlyPrice != null)
                              _buildRateTile('Monthly Rate', Formatters.formatCurrency(spot.monthlyPrice!), isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Advance Requirement Card
                  ParkCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.neonLime : AppColors.accentLight).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.payments_outlined,
                            color: isDark ? AppColors.neonLime : AppColors.accentLight,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                spot.advanceRequirementPercentage > 0
                                    ? '${spot.advanceRequirementPercentage.toStringAsFixed(0)}% Advance Required'
                                    : 'No Advance Required',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                spot.advanceRequirementPercentage > 0
                                    ? 'Advance is collected upon booking confirmation.'
                                    : 'Pay full amount when parking.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Allowed Vehicle Types & Capacity
                  ParkCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allowed Vehicles',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (spot.vehicleTypes.contains('car')) ...[
                                  Icon(Icons.directions_car, size: 20, color: isDark ? AppColors.neonLime : AppColors.accentLight),
                                  const SizedBox(width: 4),
                                  const Text('Car', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 12),
                                ],
                                if (spot.vehicleTypes.contains('bike')) ...[
                                  Icon(Icons.two_wheeler, size: 20, color: isDark ? AppColors.neonLime : AppColors.accentLight),
                                  const SizedBox(width: 4),
                                  const Text('Motorbike', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Capacity',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${spot.capacity} Spot${spot.capacity > 1 ? 's' : ''}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Facilities
                  if (spot.facilities.isNotEmpty) ...[
                    Text(
                      'Available Facilities',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: spot.facilities.map((f) => _buildFacilityBadge(f, isDark)).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Host Contact Info
                  FutureBuilder<SpotWithOwner>(
                    future: _detailsFuture,
                    builder: (context, snapshot) {
                      final owner = snapshot.data?.ownerProfile;

                      return ParkCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isDark ? AppColors.neonLime : AppColors.accentLight,
                              child: Text(
                                owner?.fullName.isNotEmpty == true ? owner!.fullName[0].toUpperCase() : 'H',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.midnightNavy : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    owner?.fullName ?? 'Parking Space Host',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    spot.isContactVisible && spot.contactPhone != null
                                        ? 'Phone: ${spot.contactPhone}'
                                        : 'Contact available upon booking confirmation',
                                    style: TextStyle(
                                      fontSize: 12,
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
                  ),
                  const SizedBox(height: 24),

                  // Genuine Reviews Section
                  Text(
                    'Renter Reviews',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),

                  FutureBuilder<List<Review>>(
                    future: _reviewsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingIndicator(message: 'Loading reviews...');
                      }

                      final reviews = snapshot.data ?? [];

                      if (reviews.isEmpty) {
                        return const EmptyStateWidget(
                          icon: Icons.rate_review_outlined,
                          title: 'No Reviews Yet',
                          description: 'This parking spot has not received any reviews from verified renters yet.',
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: reviews.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final rev = reviews[index];
                          return ParkCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: List.generate(
                                        5,
                                        (i) => Icon(
                                          i < rev.rating ? Icons.star_rounded : Icons.star_border_rounded,
                                          size: 16,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      DateTimeUtils.formatBdDate(rev.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                      ),
                                    ),
                                  ],
                                ),
                                if (rev.reviewText != null && rev.reviewText!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    rev.reviewText!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  ParkButton(
                    text: 'Book Parking Spot',
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final booking = await showDialog<Booking>(
                        context: context,
                        builder: (context) => BookingDialog(spot: spot),
                      );

                      if (booking == null) return;

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Booking request created! Ref: ${booking.bookingReference}'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateTile(String label, String price, bool isDark) {
    return Column(
      children: [
        Text(
          price,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.neonLime : AppColors.accentLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildFacilityBadge(String key, bool isDark) {
    String name = key;
    IconData icon = Icons.check_circle_outline;

    switch (key) {
      case 'cctv':
        name = 'CCTV Security';
        icon = Icons.videocam_outlined;
        break;
      case 'guarded':
        name = '24/7 Guard';
        icon = Icons.security_outlined;
        break;
      case 'covered':
        name = 'Covered Roof';
        icon = Icons.roofing_outlined;
        break;
      case 'gate_pass':
        name = 'Gate Pass';
        icon = Icons.vpn_key_outlined;
        break;
      case 'ev_charging':
        name = 'EV Charging';
        icon = Icons.ev_station_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.deepBlue : AppColors.surfaceBorderLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.surfaceBorderDark : AppColors.surfaceBorderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? AppColors.neonLime : AppColors.accentLight),
          const SizedBox(width: 6),
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
