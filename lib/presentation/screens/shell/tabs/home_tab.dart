import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/parking_spot.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/repositories/driver_repository.dart';
import '../../../widgets/widgets.dart';
import '../../driver/spot_details_screen.dart';

class HomeTab extends StatefulWidget {
  final UserProfile profile;

  const HomeTab({super.key, required this.profile});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _searchController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);

  String? _selectedVehicleType;
  double? _maxHourlyPrice;
  String? _selectedDistrict;

  late Future<List<ParkingSpot>> _spotsFuture;
  late Future<List<ParkingSpot>> _recentSpotsFuture;

  @override
  void initState() {
    super.initState();
    _refreshSpots();
  }

  void _refreshSpots() {
    setState(() {
      _spotsFuture = DriverRepository.fetchPublicSpots(
        searchQuery: _searchController.text,
        vehicleType: _selectedVehicleType,
        maxHourlyPrice: _maxHourlyPrice,
        district: _selectedDistrict,
      );
      _recentSpotsFuture = DriverRepository.fetchRecentlyViewedSpots();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _refreshSpots();
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
      _refreshSpots();
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
      _refreshSpots();
    }
  }

  void _openFilterDialog() {
    double tempMaxPrice = _maxHourlyPrice ?? 300.0;
    String? tempVehicle = _selectedVehicleType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.deepBlue : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filter Parking Spots',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 20),

                // Vehicle Type Filter
                Text(
                  'Vehicle Type',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.neonLime : AppColors.accentLight,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      selected: tempVehicle == null,
                      label: const Text('All Vehicles'),
                      onSelected: (_) => setModalState(() => tempVehicle = null),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: tempVehicle == 'car',
                      label: const Text('Car'),
                      onSelected: (_) => setModalState(() => tempVehicle = 'car'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: tempVehicle == 'bike',
                      label: const Text('Motorbike'),
                      onSelected: (_) => setModalState(() => tempVehicle = 'bike'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Max Hourly Price Slider
                Text(
                  'Max Hourly Price: ৳${tempMaxPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.neonLime : AppColors.accentLight,
                  ),
                ),
                Slider(
                  value: tempMaxPrice,
                  min: 20,
                  max: 500,
                  divisions: 24,
                  activeColor: isDark ? AppColors.neonLime : AppColors.accentLight,
                  onChanged: (val) => setModalState(() => tempMaxPrice = val),
                ),
                const SizedBox(height: 24),

                ParkButton(
                  text: 'Apply Filters',
                  onPressed: () {
                    setState(() {
                      _maxHourlyPrice = tempMaxPrice;
                      _selectedVehicleType = tempVehicle;
                    });
                    Navigator.of(ctx).pop();
                    _refreshSpots();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const ParkLogoWidget(size: 32, showGlow: false),
            const SizedBox(width: 10),
            Text(
              'ParkLagbee',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _openFilterDialog,
            tooltip: 'Filter Spots',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshSpots(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Input Bar
              ParkTextField(
                controller: _searchController,
                label: 'Search Area or District in Bangladesh',
                hint: 'e.g. Mirpur, Gulshan, Dhanmondi, Uttara, Sylhet',
                prefixIcon: Icons.search_rounded,
              ),
              const SizedBox(height: 12),

              // Date & Time Picker Selector Row
              ParkCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Date
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: _pickDate,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? AppColors.neonLime : AppColors.accentLight),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    DateTimeUtils.formatBdDate(_selectedDate),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 16),

                    // Start Time
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _pickStartTime,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Time',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 14, color: isDark ? AppColors.neonLime : AppColors.accentLight),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _startTime.format(context),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 16),

                    // End Time
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _pickEndTime,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Time',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.access_time_filled_rounded, size: 14, color: isDark ? AppColors.neonLime : AppColors.accentLight),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _endTime.format(context),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ParkButton(
                      text: 'Search Spots',
                      type: ParkButtonType.primary,
                      icon: Icons.search,
                      onPressed: _refreshSpots,
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _openFilterDialog,
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Filter'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Recently Viewed Section (Shown ONLY if local history exists)
              FutureBuilder<List<ParkingSpot>>(
                future: _recentSpotsFuture,
                builder: (context, snapshot) {
                  final recentSpots = snapshot.data ?? [];
                  if (recentSpots.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recently Viewed Spots',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: recentSpots.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final spot = recentSpots[index];
                            return SizedBox(
                              width: 200,
                              child: ParkCard(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => SpotDetailsScreen(spot: spot),
                                    ),
                                  );
                                },
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      spot.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${spot.area}, ${spot.district}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      spot.hourlyPrice != null ? '${Formatters.formatCurrency(spot.hourlyPrice!)}/hr' : 'Available',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.neonLime : AppColors.accentLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),

              // Available Verified Spots Header
              Text(
                'Available Verified Parking Spots',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),

              // Real Approved Spots List
              FutureBuilder<List<ParkingSpot>>(
                future: _spotsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: LoadingIndicator(message: 'Searching available parking spots...'),
                    );
                  }

                  if (snapshot.hasError) {
                    return ParkCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.wifi_off_outlined, color: AppColors.error, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'Unable to connect: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.error, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          ParkButton(
                            text: 'Retry',
                            type: ParkButtonType.secondary,
                            onPressed: _refreshSpots,
                          ),
                        ],
                      ),
                    );
                  }

                  final spots = snapshot.data ?? [];

                  if (spots.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.search_off_rounded,
                      title: 'No Matching Spots Found',
                      description: 'No verified active parking spots matched your area search or price filter. Try searching for a broader location like "Dhaka" or "Mirpur".',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: spots.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final spot = spots[index];
                      return _buildPublicSpotCard(spot, isDark);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublicSpotCard(ParkingSpot spot, bool isDark) {
    String priceText = 'Contact Host';
    if (spot.hourlyPrice != null && spot.hourlyPrice! > 0) {
      priceText = '${Formatters.formatCurrency(spot.hourlyPrice!)} / hr';
    } else if (spot.dailyPrice != null && spot.dailyPrice! > 0) {
      priceText = '${Formatters.formatCurrency(spot.dailyPrice!)} / day';
    }

    return ParkCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SpotDetailsScreen(spot: spot),
          ),
        );
      },
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  spot.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              Text(
                priceText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.neonLime : AppColors.accentLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 15, color: isDark ? AppColors.neonLime : AppColors.accentLight),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${spot.area}, ${spot.district}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (spot.vehicleTypes.contains('car')) ...[
                Icon(Icons.directions_car, size: 16, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                const SizedBox(width: 4),
                const Text('Car', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 10),
              ],
              if (spot.vehicleTypes.contains('bike')) ...[
                Icon(Icons.two_wheeler, size: 16, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                const SizedBox(width: 4),
                const Text('Motorbike', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 10),
              ],
              if (spot.advanceRequirementPercentage > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${spot.advanceRequirementPercentage.toStringAsFixed(0)}% Advance Req',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
