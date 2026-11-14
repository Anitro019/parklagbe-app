import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_slot_calculator.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/parking_spot.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/spot_repository.dart';
import '../../widgets/widgets.dart';

class BookingDialog extends StatefulWidget {
  final ParkingSpot spot;

  const BookingDialog({super.key, required this.spot});

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();

  DateTime _bookingDate = DateTime.now();
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  late TimeOfDay _opStart;
  late TimeOfDay _opEnd;

  String _selectedVehicle = 'car';
  final String _rentalType = 'hourly';

  List<Booking> _activeBookingsForDate = [];
  bool _isLoadingSlots = false;

  bool _isLoading = false;
  String? _errorMessage;
  Timer? _availabilityTimer;

  @override
  void initState() {
    super.initState();
    if (widget.spot.vehicleTypes.isNotEmpty) {
      _selectedVehicle = widget.spot.vehicleTypes.first;
    }
    final availableFrom = widget.spot.effectiveAvailableFrom;
    if (availableFrom != null &&
        availableFrom.isAfter(DateTime.now().toUtc())) {
      final startDate = DateTimeUtils.toBangladeshTime(availableFrom);
      _bookingDate = DateTime(startDate.year, startDate.month, startDate.day);
    }

    _opStart = TimeSlotCalculator.parseTime(
      widget.spot.availableHoursStart,
      const TimeOfDay(hour: 0, minute: 0),
    );
    _opEnd = TimeSlotCalculator.parseTime(
      widget.spot.availableHoursEnd,
      const TimeOfDay(hour: 23, minute: 59),
    );

    final now = TimeOfDay.now();
    if (_isTimeWithinBounds(now, _opStart, _opEnd)) {
      _startTime = now;
      final endHour = (now.hour + 1) > _opEnd.hour
          ? _opEnd.hour
          : (now.hour + 1);
      _endTime = TimeOfDay(hour: endHour, minute: now.minute);
    } else {
      _startTime = _opStart;
      final endHour = (_opStart.hour + 1) > _opEnd.hour
          ? _opEnd.hour
          : (_opStart.hour + 1);
      _endTime = TimeOfDay(
        hour: _opStart.hour == 23 ? 23 : endHour,
        minute: _opStart.minute,
      );
    }

    _loadActiveBookingsForDate(_bookingDate);
    _scheduleAvailabilityRefresh();
  }

  Future<void> _loadActiveBookingsForDate(DateTime date) async {
    setState(() => _isLoadingSlots = true);
    try {
      final bookings = await SpotRepository.fetchActiveBookingsForSpotDate(
        widget.spot.id,
        date,
      );
      if (mounted) {
        setState(() {
          _activeBookingsForDate = bookings;
          _isLoadingSlots = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  bool _isTimeWithinBounds(TimeOfDay target, TimeOfDay start, TimeOfDay end) {
    final targetMins = target.hour * 60 + target.minute;
    final startMins = start.hour * 60 + start.minute;
    final endMins = end.hour * 60 + end.minute;
    return targetMins >= startMins && targetMins <= endMins;
  }

  @override
  void dispose() {
    _availabilityTimer?.cancel();
    _plateController.dispose();
    super.dispose();
  }

  void _scheduleAvailabilityRefresh() {
    _availabilityTimer?.cancel();
    final end = widget.spot.effectiveAvailableTo;
    if (end == null || !end.isAfter(DateTime.now().toUtc())) return;
    _availabilityTimer = Timer(end.difference(DateTime.now().toUtc()), () {
      if (mounted) setState(() => _availabilityTimer = null);
    });
  }

  DateTime _getStartDateTime() {
    return DateTime.utc(
      _bookingDate.year,
      _bookingDate.month,
      _bookingDate.day,
      _startTime.hour,
      _startTime.minute,
    ).subtract(const Duration(hours: 6));
  }

  DateTime _getEndDateTime() {
    var end = DateTime.utc(
      _bookingDate.year,
      _bookingDate.month,
      _bookingDate.day,
      _endTime.hour,
      _endTime.minute,
    ).subtract(const Duration(hours: 6));
    if (end.isBefore(_getStartDateTime())) {
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  DateTime get _minimumBookingDate {
    final today = DateTimeUtils.toBangladeshTime(DateTime.now());
    final availableFrom = widget.spot.effectiveAvailableFrom;
    if (availableFrom == null) {
      return DateTime(today.year, today.month, today.day);
    }
    final start = DateTimeUtils.toBangladeshTime(availableFrom);
    final startDate = DateTime(start.year, start.month, start.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    return startDate.isAfter(todayDate) ? startDate : todayDate;
  }

  DateTime get _maximumBookingDate {
    final today = DateTimeUtils.toBangladeshTime(DateTime.now());
    final availableTo = widget.spot.effectiveAvailableTo;
    final minimumDate = _minimumBookingDate;
    var latestAllowedDate = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 60));
    if (latestAllowedDate.isBefore(minimumDate)) {
      latestAllowedDate = minimumDate;
    }
    if (availableTo == null) return latestAllowedDate;
    final end = DateTimeUtils.toBangladeshTime(availableTo);
    final endDate = DateTime(end.year, end.month, end.day);
    return endDate.isBefore(latestAllowedDate) ? endDate : latestAllowedDate;
  }

  double _calculateDurationHours() {
    final start = _getStartDateTime();
    final end = _getEndDateTime();
    final diffMinutes = end.difference(start).inMinutes;
    return (diffMinutes / 60.0).clamp(0.1, 720.0);
  }

  double _calculateTotalPrice() {
    final hours = _calculateDurationHours();
    final rate = widget.spot.hourlyPrice ?? 50.0;
    return hours * rate;
  }

  double _calculateAdvanceAmount() {
    final total = _calculateTotalPrice();
    final pct = widget.spot.advanceRequirementPercentage;
    return (total * (pct / 100.0));
  }

  Future<void> _callOwner(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not place call to $phone')));
    }
  }

  Future<void> _handleConfirmBooking() async {
    if (!_formKey.currentState!.validate()) return;

    final start = _getStartDateTime();
    final end = _getEndDateTime();
    final now = DateTime.now().toUtc();

    if (widget.spot.isExpired) {
      setState(
        () => _errorMessage = 'This listing has expired and cannot be booked.',
      );
      return;
    }

    if (!end.isAfter(now)) {
      setState(() => _errorMessage = 'Booking end time must be in the future.');
      return;
    }

    if (!end.isAfter(start)) {
      setState(
        () => _errorMessage = 'End time must be strictly after start time.',
      );
      return;
    }

    final availableFrom = widget.spot.effectiveAvailableFrom;
    if (availableFrom != null && start.isBefore(availableFrom)) {
      setState(
        () => _errorMessage =
            'Booking cannot start before this listing is available.',
      );
      return;
    }
    final availableTo = widget.spot.effectiveAvailableTo;
    if (availableTo != null && end.isAfter(availableTo)) {
      setState(
        () => _errorMessage = 'Booking must end before this listing expires.',
      );
      return;
    }

    // Minimum 1 Hour Booking Requirement Check
    final durationMins = end.difference(start).inMinutes;
    if (durationMins < 60) {
      setState(() => _errorMessage = 'Minimum booking duration is 1 hour.');
      return;
    }

    if (!_isTimeWithinBounds(_startTime, _opStart, _opEnd) ||
        !_isTimeWithinBounds(_endTime, _opStart, _opEnd)) {
      setState(
        () => _errorMessage =
            'Selected time window is outside operating hours (${_opStart.format(context)} to ${_opEnd.format(context)}).',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final booking = await BookingRepository.createBookingRequest(
        spotId: widget.spot.id,
        vehicleType: _selectedVehicle,
        vehicleNumber: _plateController.text.trim().isNotEmpty
            ? _plateController.text.trim()
            : null,
        bookingDate: _bookingDate,
        startTime: start,
        endTime: end,
        rentalType: _rentalType,
      );

      if (mounted) {
        Navigator.of(context).pop<Booking>(booking);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final durationHours = _calculateDurationHours();
    final totalPrice = _calculateTotalPrice();
    final advanceAmount = _calculateAdvanceAmount();
    final dueOnArrival = totalPrice - advanceAmount;

    final availabilityStatusText = TimeSlotCalculator.formatAvailabilityStatus(
      context,
      spot: widget.spot,
      date: _bookingDate,
      activeBookingsOnDate: _activeBookingsForDate,
    );

    final isFullyBookedOrExpired =
        widget.spot.isExpired ||
        availabilityStatusText.contains('Fully Booked') ||
        availabilityStatusText.contains('Expired');

    return Dialog(
      backgroundColor: isDark ? AppColors.deepBlue : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Book Parking Slot',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Dynamic Real-Time Slot Indicator Status Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isFullyBookedOrExpired
                      ? AppColors.error.withValues(alpha: 0.15)
                      : (isDark ? AppColors.neonLime : AppColors.accentLight)
                            .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFullyBookedOrExpired
                        ? AppColors.error
                        : (isDark ? AppColors.neonLime : AppColors.accentLight),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFullyBookedOrExpired
                          ? Icons.event_busy_rounded
                          : Icons.schedule_rounded,
                      size: 20,
                      color: isFullyBookedOrExpired
                          ? AppColors.error
                          : (isDark
                                ? AppColors.neonLime
                                : AppColors.accentLight),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isLoadingSlots
                            ? 'Calculating available hours...'
                            : availabilityStatusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isFullyBookedOrExpired
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
              const SizedBox(height: 12),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Vehicle Type Chips
              Text(
                'Select Vehicle Type',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.neonLime : AppColors.accentLight,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (widget.spot.vehicleTypes.contains('car'))
                    FilterChip(
                      selected: _selectedVehicle == 'car',
                      label: const Text('Car / SUV'),
                      onSelected: (_) =>
                          setState(() => _selectedVehicle = 'car'),
                    ),
                  if (widget.spot.vehicleTypes.contains('bike'))
                    FilterChip(
                      selected: _selectedVehicle == 'bike',
                      label: const Text('Motorbike'),
                      onSelected: (_) =>
                          setState(() => _selectedVehicle = 'bike'),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // License Plate Number
              ParkTextField(
                controller: _plateController,
                label: 'Vehicle License Plate (Optional)',
                hint: 'e.g. Dhaka Metro-GA-11-2233',
              ),
              const SizedBox(height: 16),

              // Date & Dynamic Time Selectors
              Text(
                'Date & Time Window (Minimum 1 Hour)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.neonLime : AppColors.accentLight,
                ),
              ),
              const SizedBox(height: 8),
              ParkCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                      ),
                      title: const Text(
                        'Booking Date',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: SizedBox(
                        width: 84,
                        child: Text(
                          DateTimeUtils.formatBdDate(_bookingDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      onTap: widget.spot.isExpired
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _bookingDate,
                                firstDate: _minimumBookingDate,
                                lastDate: _maximumBookingDate,
                              );
                              if (picked != null) {
                                setState(() => _bookingDate = picked);
                                _loadActiveBookingsForDate(picked);
                              }
                            },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time_rounded, size: 20),
                      title: const Text(
                        'Start Time',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: SizedBox(
                        width: 70,
                        child: Text(
                          _startTime.format(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final startOpStr = _opStart.format(context);
                        final endOpStr = _opEnd.format(context);

                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (picked != null) {
                          if (!_isTimeWithinBounds(picked, _opStart, _opEnd)) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Start time must be within operating hours ($startOpStr to $endOpStr)',
                                ),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          }
                          setState(() => _startTime = picked);
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.access_time_filled_rounded,
                        size: 20,
                      ),
                      title: const Text(
                        'End Time',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: SizedBox(
                        width: 70,
                        child: Text(
                          _endTime.format(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final startOpStr = _opStart.format(context);
                        final endOpStr = _opEnd.format(context);

                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (picked != null) {
                          if (!_isTimeWithinBounds(picked, _opStart, _opEnd)) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'End time must be within operating hours ($startOpStr to $endOpStr)',
                                ),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          }
                          setState(() => _endTime = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Owner Contact Section (Call Owner Button)
              if (widget.spot.isContactVisible &&
                  widget.spot.contactPhone != null &&
                  widget.spot.contactPhone!.isNotEmpty) ...[
                ParkCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_in_talk_rounded,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Owner Phone Contact',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.spot.contactPhone!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.call, size: 16),
                          label: const Text('Call Owner'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () =>
                              _callOwner(widget.spot.contactPhone!),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Dynamic Price Breakdown Card
              ParkCard(
                showGlowBorder: true,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark
                            ? AppColors.neonLime
                            : AppColors.accentLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildRow(
                      'Rate',
                      '${Formatters.formatCurrency(widget.spot.hourlyPrice ?? 50.0)} / hr',
                    ),
                    _buildRow(
                      'Duration',
                      '${durationHours.toStringAsFixed(1)} hrs',
                    ),
                    const Divider(height: 12),
                    _buildRow(
                      'Total Rental Cost',
                      Formatters.formatCurrency(totalPrice),
                      isBold: true,
                    ),
                    if (widget.spot.advanceRequirementPercentage > 0) ...[
                      _buildRow(
                        'Advance Required (${widget.spot.advanceRequirementPercentage.toStringAsFixed(0)}%)',
                        Formatters.formatCurrency(advanceAmount),
                        color: AppColors.warning,
                      ),
                      _buildRow(
                        'Due on Arrival',
                        Formatters.formatCurrency(dueOnArrival),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ParkButton(
                text: isFullyBookedOrExpired
                    ? 'Fully Booked / Unavailable'
                    : 'Send Booking Request',
                isLoading: _isLoading,
                onPressed: isFullyBookedOrExpired
                    ? null
                    : _handleConfirmBooking,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
