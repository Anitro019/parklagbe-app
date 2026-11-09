import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/parking_spot.dart';
import '../../../data/repositories/booking_repository.dart';
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

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.spot.vehicleTypes.isNotEmpty) {
      _selectedVehicle = widget.spot.vehicleTypes.first;
    }

    // Parse spot operational hours
    _opStart = _parseTimeOfDay(widget.spot.availableHoursStart, const TimeOfDay(hour: 0, minute: 0));
    _opEnd = _parseTimeOfDay(widget.spot.availableHoursEnd, const TimeOfDay(hour: 23, minute: 59));

    // Initialize Start Time & End Time within spot operational hours
    final now = TimeOfDay.now();
    if (_isTimeWithinBounds(now, _opStart, _opEnd)) {
      _startTime = now;
      // Default to 1 hour duration (not forcing 2 hours)
      final endHour = (now.hour + 1) > _opEnd.hour ? _opEnd.hour : (now.hour + 1);
      _endTime = TimeOfDay(hour: endHour, minute: now.minute);
    } else {
      _startTime = _opStart;
      final endHour = (_opStart.hour + 1) > _opEnd.hour ? _opEnd.hour : (_opStart.hour + 1);
      _endTime = TimeOfDay(hour: endHour, minute: _opStart.minute);
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr, TimeOfDay fallback) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return fallback;
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
    _plateController.dispose();
    super.dispose();
  }

  DateTime _getStartDateTime() {
    return DateTime(
      _bookingDate.year,
      _bookingDate.month,
      _bookingDate.day,
      _startTime.hour,
      _startTime.minute,
    );
  }

  DateTime _getEndDateTime() {
    var end = DateTime(
      _bookingDate.year,
      _bookingDate.month,
      _bookingDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    if (end.isBefore(_getStartDateTime())) {
      end = end.add(const Duration(days: 1));
    }
    return end;
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

  Future<void> _handleConfirmBooking() async {
    if (!_formKey.currentState!.validate()) return;

    final start = _getStartDateTime();
    final end = _getEndDateTime();

    if (!end.isAfter(start)) {
      setState(() => _errorMessage = 'End time must be strictly after start time.');
      return;
    }

    if (!_isTimeWithinBounds(_startTime, _opStart, _opEnd) || !_isTimeWithinBounds(_endTime, _opStart, _opEnd)) {
      setState(() => _errorMessage = 'Selected time window is outside operating hours (${_opStart.format(context)} to ${_opEnd.format(context)}).');
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
        vehicleNumber: _plateController.text.trim().isNotEmpty ? _plateController.text.trim() : null,
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
                  Text(
                    'Book Parking Slot',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Operating Hours Notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.neonLime : AppColors.accentLight).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.neonLime : AppColors.accentLight),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 18, color: isDark ? AppColors.neonLime : AppColors.accentLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Operating Hours: ${_opStart.format(context)} - ${_opEnd.format(context)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.neonLime : AppColors.accentLight),
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
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
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
              Row(
                children: [
                  if (widget.spot.vehicleTypes.contains('car'))
                    Expanded(
                      child: FilterChip(
                        selected: _selectedVehicle == 'car',
                        label: const Text('Car / SUV'),
                        onSelected: (_) => setState(() => _selectedVehicle = 'car'),
                      ),
                    ),
                  if (widget.spot.vehicleTypes.contains('car') && widget.spot.vehicleTypes.contains('bike'))
                    const SizedBox(width: 8),
                  if (widget.spot.vehicleTypes.contains('bike'))
                    Expanded(
                      child: FilterChip(
                        selected: _selectedVehicle == 'bike',
                        label: const Text('Motorbike'),
                        onSelected: (_) => setState(() => _selectedVehicle = 'bike'),
                      ),
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
                'Date & Time Window',
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
                      leading: const Icon(Icons.calendar_today_rounded, size: 20),
                      title: const Text('Booking Date'),
                      trailing: Text(
                        DateTimeUtils.formatBdDate(_bookingDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _bookingDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 60)),
                        );
                        if (picked != null) setState(() => _bookingDate = picked);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time_rounded, size: 20),
                      title: const Text('Start Time'),
                      trailing: Text(
                        _startTime.format(context),
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                                content: Text('Start time must be within operating hours ($startOpStr to $endOpStr)'),
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
                      leading: const Icon(Icons.access_time_filled_rounded, size: 20),
                      title: const Text('End Time'),
                      trailing: Text(
                        _endTime.format(context),
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                                content: Text('End time must be within operating hours ($startOpStr to $endOpStr)'),
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
                        color: isDark ? AppColors.neonLime : AppColors.accentLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildRow('Rate', '${Formatters.formatCurrency(widget.spot.hourlyPrice ?? 50.0)} / hr'),
                    _buildRow('Duration', '${durationHours.toStringAsFixed(1)} hrs'),
                    const Divider(height: 12),
                    _buildRow('Total Rental Cost', Formatters.formatCurrency(totalPrice), isBold: true),
                    if (widget.spot.advanceRequirementPercentage > 0) ...[
                      _buildRow('Advance Required (${widget.spot.advanceRequirementPercentage.toStringAsFixed(0)}%)', Formatters.formatCurrency(advanceAmount), color: AppColors.warning),
                      _buildRow('Due on Arrival', Formatters.formatCurrency(dueOnArrival)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ParkButton(
                text: 'Send Booking Request',
                isLoading: _isLoading,
                onPressed: _handleConfirmBooking,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
