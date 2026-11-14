import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/permission_disclosures.dart';
import '../../../data/models/parking_photo.dart';
import '../../../data/models/parking_spot.dart';
import '../../../data/repositories/spot_repository.dart';
import '../../widgets/widgets.dart';

class AddEditSpotScreen extends StatefulWidget {
  final String ownerId;
  final ParkingSpot? spot; // Null for new spot, non-null for editing

  const AddEditSpotScreen({super.key, required this.ownerId, this.spot});

  @override
  State<AddEditSpotScreen> createState() => _AddEditSpotScreenState();
}

class _AddEditSpotScreenState extends State<AddEditSpotScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _divisionController;
  late TextEditingController _districtController;
  late TextEditingController _areaController;
  late TextEditingController _addressController;
  late TextEditingController _mapsUrlController;
  late TextEditingController _capacityController;
  late TextEditingController _hourlyPriceController;
  late TextEditingController _dailyPriceController;
  late TextEditingController _monthlyPriceController;
  late TextEditingController _advanceReqController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _rulesController;

  // Selections
  bool _allowCar = true;
  bool _allowBike = false;
  bool _isContactVisible = true;

  TimeOfDay _availableStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _availableEnd = const TimeOfDay(hour: 22, minute: 0);

  DateTime? _availableStartDate = DateTime.now();
  DateTime? _availableEndDate = DateTime.now().add(const Duration(days: 30));

  final List<String> _selectedDays = [
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];
  final List<String> _allDays = [
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];
  final Map<String, String> _dayLabels = {
    'mon': 'Mon',
    'tue': 'Tue',
    'wed': 'Wed',
    'thu': 'Thu',
    'fri': 'Fri',
    'sat': 'Sat',
    'sun': 'Sun',
  };

  final List<String> _selectedFacilities = ['cctv', 'guarded'];

  // Photos
  List<ParkingPhoto> _existingPhotos = [];
  final List<String> _deletePhotoIds = [];
  final List<File> _newPhotoFiles = [];
  final List<Uint8List> _newPhotoBytes = [];

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final s = widget.spot;

    _titleController = TextEditingController(text: s?.title ?? '');
    _descriptionController = TextEditingController(text: s?.description ?? '');
    _divisionController = TextEditingController(text: s?.division ?? 'Dhaka');
    _districtController = TextEditingController(text: s?.district ?? 'Dhaka');
    _areaController = TextEditingController(text: s?.area ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _mapsUrlController = TextEditingController(text: s?.googleMapsUrl ?? '');
    _capacityController = TextEditingController(
      text: (s?.capacity ?? 1).toString(),
    );
    _hourlyPriceController = TextEditingController(
      text: s?.hourlyPrice != null ? s!.hourlyPrice!.toStringAsFixed(0) : '',
    );
    _dailyPriceController = TextEditingController(
      text: s?.dailyPrice != null ? s!.dailyPrice!.toStringAsFixed(0) : '',
    );
    _monthlyPriceController = TextEditingController(
      text: s?.monthlyPrice != null ? s!.monthlyPrice!.toStringAsFixed(0) : '',
    );
    _advanceReqController = TextEditingController(
      text: (s?.advanceRequirementPercentage ?? 0).toStringAsFixed(0),
    );
    _contactPhoneController = TextEditingController(
      text: s?.contactPhone ?? '',
    );
    _rulesController = TextEditingController(text: s?.rules ?? '');

    if (s != null) {
      _allowCar = s.vehicleTypes.contains('car');
      _allowBike = s.vehicleTypes.contains('bike');
      _isContactVisible = s.isContactVisible;
      _selectedDays.clear();
      _selectedDays.addAll(s.availableDays);
      _selectedFacilities.clear();
      _selectedFacilities.addAll(s.facilities);

      _availableStart = _parseTime(
        s.availableHoursStart,
        const TimeOfDay(hour: 8, minute: 0),
      );
      _availableEnd = _parseTime(
        s.availableHoursEnd,
        const TimeOfDay(hour: 22, minute: 0),
      );

      _availableStartDate = s.availableStartDate ?? DateTime.now();
      _availableEndDate =
          s.availableEndDate ?? DateTime.now().add(const Duration(days: 30));

      _loadExistingPhotos(s.id);
    }
  }

  TimeOfDay _parseTime(String? timeStr, TimeOfDay fallback) {
    if (timeStr == null || timeStr.isEmpty) return fallback;
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _loadExistingPhotos(String spotId) async {
    try {
      final photos = await SpotRepository.fetchSpotPhotos(spotId);
      if (mounted) {
        setState(() {
          _existingPhotos = photos;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _divisionController.dispose();
    _districtController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _mapsUrlController.dispose();
    _capacityController.dispose();
    _hourlyPriceController.dispose();
    _dailyPriceController.dispose();
    _monthlyPriceController.dispose();
    _advanceReqController.dispose();
    _contactPhoneController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (!await PermissionDisclosures.showMediaDisclosure(context)) return;

    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 80);

    if (pickedFiles.isNotEmpty) {
      if (kIsWeb) {
        for (final pf in pickedFiles) {
          final bytes = await pf.readAsBytes();
          setState(() => _newPhotoBytes.add(bytes));
        }
      } else {
        setState(() {
          _newPhotoFiles.addAll(pickedFiles.map((pf) => File(pf.path)));
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_allowCar && !_allowBike) {
      setState(
        () => _errorMessage = 'Select at least one allowed vehicle type.',
      );
      return;
    }

    if (_selectedDays.isEmpty) {
      setState(
        () => _errorMessage = 'Select at least one operating day of the week.',
      );
      return;
    }

    // Minimum 2 Spot Photos Enforced (Requirement 6)
    final totalPhotoCount =
        _existingPhotos.length -
        _deletePhotoIds.length +
        (kIsWeb ? _newPhotoBytes.length : _newPhotoFiles.length);
    if (totalPhotoCount < 2) {
      setState(
        () => _errorMessage = 'Minimum 2 clear spot photos are required for listing verification. Please add more photos.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vehicleTypes = <String>[];
      if (_allowCar) vehicleTypes.add('car');
      if (_allowBike) vehicleTypes.add('bike');

      final hourlyText = _hourlyPriceController.text.trim();
      final dailyText = _dailyPriceController.text.trim();
      final monthlyText = _monthlyPriceController.text.trim();

      final hourly = hourlyText.isNotEmpty ? double.tryParse(hourlyText) : null;
      final daily = dailyText.isNotEmpty ? double.tryParse(dailyText) : null;
      final monthly = monthlyText.isNotEmpty ? double.tryParse(monthlyText) : null;

      // Validate that AT LEAST ONE pricing option is provided and positive
      final hasHourly = hourly != null && hourly > 0;
      final hasDaily = daily != null && daily > 0;
      final hasMonthly = monthly != null && monthly > 0;

      if (!hasHourly && !hasDaily && !hasMonthly) {
        setState(
          () => _errorMessage = 'Please enter at least one pricing rate (Hourly, Daily, or Monthly).',
        );
        return;
      }

      final mapsUrl = _mapsUrlController.text.trim();
      final contactPhone = _contactPhoneController.text.trim();

      final startStr =
          '${_availableStart.hour.toString().padLeft(2, '0')}:${_availableStart.minute.toString().padLeft(2, '0')}:00';
      final endStr =
          '${_availableEnd.hour.toString().padLeft(2, '0')}:${_availableEnd.minute.toString().padLeft(2, '0')}:00';

      if (widget.spot == null) {
        // Create
        await SpotRepository.createSpot(
          ownerId: widget.ownerId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          division: _divisionController.text.trim(),
          district: _districtController.text.trim(),
          area: _areaController.text.trim(),
          address: _addressController.text.trim(),
          googleMapsUrl: mapsUrl.isNotEmpty ? mapsUrl : null,
          vehicleTypes: vehicleTypes,
          capacity: int.parse(_capacityController.text.trim()),
          hourlyPrice: hourly,
          dailyPrice: daily,
          monthlyPrice: monthly,
          availableHoursStart: startStr,
          availableHoursEnd: endStr,
          availableDays: _selectedDays,
          availableStartDate: _availableStartDate,
          availableEndDate: _availableEndDate,
          rules: _rulesController.text.trim(),
          facilities: _selectedFacilities,
          advanceRequirementPercentage:
              double.tryParse(_advanceReqController.text.trim()) ?? 0.0,
          contactPhone: contactPhone.isNotEmpty ? contactPhone : null,
          isContactVisible: _isContactVisible,
          newPhotoFiles: _newPhotoFiles,
          newPhotoBytes: _newPhotoBytes,
        );
      } else {
        // Update
        await SpotRepository.updateSpot(
          spotId: widget.spot!.id,
          ownerId: widget.ownerId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          division: _divisionController.text.trim(),
          district: _districtController.text.trim(),
          area: _areaController.text.trim(),
          address: _addressController.text.trim(),
          googleMapsUrl: mapsUrl.isNotEmpty ? mapsUrl : null,
          vehicleTypes: vehicleTypes,
          capacity: int.parse(_capacityController.text.trim()),
          hourlyPrice: hourly,
          dailyPrice: daily,
          monthlyPrice: monthly,
          availableHoursStart: startStr,
          availableHoursEnd: endStr,
          availableDays: _selectedDays,
          availableStartDate: _availableStartDate,
          availableEndDate: _availableEndDate,
          rules: _rulesController.text.trim(),
          facilities: _selectedFacilities,
          advanceRequirementPercentage:
              double.tryParse(_advanceReqController.text.trim()) ?? 0.0,
          contactPhone: contactPhone.isNotEmpty ? contactPhone : null,
          isContactVisible: _isContactVisible,
          newPhotoFiles: _newPhotoFiles,
          newPhotoBytes: _newPhotoBytes,
          deletePhotoIds: _deletePhotoIds,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.spot == null
                  ? 'Parking spot published successfully! It is now live.'
                  : 'Parking spot updated successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.spot == null ? 'List New Parking Spot' : 'Edit Parking Spot',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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

                // Section 1: Location & Details
                _buildSectionHeader('1. Location & Details', isDark),
                const SizedBox(height: 12),
                ParkTextField(
                  controller: _titleController,
                  label: 'Listing Title',
                  hint: 'e.g. Covered Garage Spot in Gulshan 2',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter title' : null,
                ),
                const SizedBox(height: 12),
                ParkTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Describe gate access, security, guidelines...',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ParkTextField(
                        controller: _divisionController,
                        label: 'Division',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter division'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ParkTextField(
                        controller: _districtController,
                        label: 'District',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter district'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ParkTextField(
                  controller: _areaController,
                  label: 'Area / Neighborhood',
                  hint: 'e.g. Gulshan 2, Dhanmondi, Uttara',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter area' : null,
                ),
                const SizedBox(height: 12),
                ParkTextField(
                  controller: _addressController,
                  label: 'Full Street Address',
                  hint: 'e.g. House 14, Road 11, Block D',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter address' : null,
                ),
                const SizedBox(height: 12),
                ParkTextField(
                  controller: _mapsUrlController,
                  label: 'Google Maps Link (Optional)',
                  hint: 'https://maps.google.com/?q=...',
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      final uri = Uri.tryParse(v.trim());
                      if (uri == null || !uri.hasScheme) {
                        return 'Enter a valid URL';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Section 2: Availability Date Range & Operating Hours
                _buildSectionHeader(
                  '2. Availability Date Range & Operating Hours',
                  isDark,
                ),
                const SizedBox(height: 12),
                ParkCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Availability Date Range',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.neonLime
                              : AppColors.accentLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set when your parking space is active (e.g. Nov 1 to Nov 15, or full month)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.calendar_today_rounded,
                                size: 20,
                              ),
                              title: const Text('Start Date'),
                              subtitle: Text(
                                _availableStartDate != null
                                    ? '${_availableStartDate!.day}/${_availableStartDate!.month}/${_availableStartDate!.year}'
                                    : 'Select',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _availableStartDate ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 30),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _availableStartDate = picked);
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.event_available_rounded,
                                size: 20,
                              ),
                              title: const Text('End Date'),
                              subtitle: Text(
                                _availableEndDate != null
                                    ? '${_availableEndDate!.day}/${_availableEndDate!.month}/${_availableEndDate!.year}'
                                    : 'Select',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _availableEndDate ??
                                      DateTime.now().add(
                                        const Duration(days: 30),
                                      ),
                                  firstDate:
                                      _availableStartDate ?? DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _availableEndDate = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('Next 14 Days'),
                            onPressed: () {
                              setState(() {
                                _availableStartDate = DateTime.now();
                                _availableEndDate = DateTime.now().add(
                                  const Duration(days: 14),
                                );
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text('Full Month (30 Days)'),
                            onPressed: () {
                              setState(() {
                                _availableStartDate = DateTime.now();
                                _availableEndDate = DateTime.now().add(
                                  const Duration(days: 30),
                                );
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text('Next 60 Days'),
                            onPressed: () {
                              setState(() {
                                _availableStartDate = DateTime.now();
                                _availableEndDate = DateTime.now().add(
                                  const Duration(days: 60),
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        'Operating Hours Window',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.neonLime
                              : AppColors.accentLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.access_time_rounded),
                              title: const Text('Opens At'),
                              subtitle: Text(
                                _availableStart.format(context),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _availableStart,
                                );
                                if (picked != null) {
                                  setState(() => _availableStart = picked);
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.access_time_filled_rounded,
                              ),
                              title: const Text('Closes At'),
                              subtitle: Text(
                                _availableEnd.format(context),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _availableEnd,
                                );
                                if (picked != null) {
                                  setState(() => _availableEnd = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Available Operating Days',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.neonLime
                              : AppColors.accentLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _allDays.map((day) {
                          final isSelected = _selectedDays.contains(day);
                          return FilterChip(
                            selected: isSelected,
                            label: Text(_dayLabels[day] ?? day),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedDays.add(day);
                                } else {
                                  _selectedDays.remove(day);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 3: Vehicle Type & Capacity
                _buildSectionHeader('3. Vehicle Type & Capacity', isDark),
                const SizedBox(height: 12),
                ParkCard(
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: _allowCar,
                        title: const Text('Car / Microbus / SUV'),
                        activeColor: isDark
                            ? AppColors.neonLime
                            : AppColors.accentLight,
                        checkColor: isDark
                            ? AppColors.midnightNavy
                            : Colors.white,
                        onChanged: (val) =>
                            setState(() => _allowCar = val ?? false),
                      ),
                      const Divider(height: 1),
                      CheckboxListTile(
                        value: _allowBike,
                        title: const Text('Motorbike / Scooter'),
                        activeColor: isDark
                            ? AppColors.neonLime
                            : AppColors.accentLight,
                        checkColor: isDark
                            ? AppColors.midnightNavy
                            : Colors.white,
                        onChanged: (val) =>
                            setState(() => _allowBike = val ?? false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ParkTextField(
                  controller: _capacityController,
                  label: 'Vehicle Capacity (Number of spots)',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) {
                      return 'Capacity must be at least 1';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Section 4: Pricing (BDT ৳)
                _buildSectionHeader('4. Pricing (BDT ৳ - Fill At Least One Option)', isDark),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 280
                        ? 1
                        : (constraints.maxWidth >= 560 ? 3 : 2);
                    final fieldWidth =
                        (constraints.maxWidth - (columns - 1) * 8) / columns;

                    return Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: ParkTextField(
                        controller: _hourlyPriceController,
                        label: 'Hourly (৳)',
                        hint: '100',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final p = double.tryParse(v.trim());
                            if (p == null || p <= 0) return 'Must be > 0';
                          }
                          return null;
                        },
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: ParkTextField(
                        controller: _dailyPriceController,
                        label: 'Daily (৳)',
                        hint: '800',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final p = double.tryParse(v.trim());
                            if (p == null || p <= 0) return 'Must be > 0';
                          }
                          return null;
                        },
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: ParkTextField(
                        controller: _monthlyPriceController,
                        label: 'Monthly (৳)',
                        hint: '6000',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final p = double.tryParse(v.trim());
                            if (p == null || p <= 0) return 'Must be > 0';
                          }
                          return null;
                        },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                ParkTextField(
                  controller: _advanceReqController,
                  label: 'Advance Booking Requirement (%)',
                  hint: '0 to 100',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final p = double.tryParse(v ?? '0');
                    if (p == null || p < 0 || p > 100) {
                      return 'Enter % between 0 and 100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Section 5: Contact Settings
                _buildSectionHeader('5. Contact & Visibility', isDark),
                const SizedBox(height: 12),
                ParkTextField(
                  controller: _contactPhoneController,
                  label: 'Contact Phone Number (Optional)',
                  hint: 'e.g. +8801700000000',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                ParkCard(
                  child: SwitchListTile(
                    value: _isContactVisible,
                    title: const Text('Show Contact Phone to Renters'),
                    subtitle: const Text(
                      'Allow renters to see phone number upon booking confirmation',
                    ),
                    activeTrackColor: isDark
                        ? AppColors.neonLime
                        : AppColors.accentLight,
                    activeThumbColor: isDark
                        ? AppColors.midnightNavy
                        : Colors.white,
                    onChanged: (val) => setState(() => _isContactVisible = val),
                  ),
                ),
                const SizedBox(height: 24),

                // Section 6: Photos Upload
                _buildSectionHeader('6. Spot Photos', isDark),
                const SizedBox(height: 12),
                _buildPhotoSelector(isDark),
                const SizedBox(height: 32),

                ParkButton(
                  text: widget.spot == null
                      ? 'Publish Parking Spot'
                      : 'Update Parking Spot',
                  isLoading: _isLoading,
                  onPressed: _handleSubmit,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.neonLime : AppColors.accentLight,
      ),
    );
  }

  Widget _buildPhotoSelector(bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Existing Photos
        for (final photo in _existingPhotos)
          if (!_deletePhotoIds.contains(photo.id))
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    photo.storagePath,
                    width: 85,
                    height: 85,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: InkWell(
                    onTap: () {
                      setState(() => _deletePhotoIds.add(photo.id));
                    },
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black.withValues(alpha: 0.7),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),

        // New Web Photos
        if (kIsWeb)
          for (int i = 0; i < _newPhotoBytes.length; i++)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    _newPhotoBytes[i],
                    width: 85,
                    height: 85,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: InkWell(
                    onTap: () {
                      setState(() => _newPhotoBytes.removeAt(i));
                    },
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black.withValues(alpha: 0.7),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),

        // New Native File Photos
        for (int i = 0; i < _newPhotoFiles.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  _newPhotoFiles[i],
                  width: 85,
                  height: 85,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: () {
                    setState(() => _newPhotoFiles.removeAt(i));
                  },
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black.withValues(alpha: 0.7),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

        // Add Photo Button
        InkWell(
          onTap: _pickPhotos,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 85,
            height: 85,
            decoration: BoxDecoration(
              color: isDark ? AppColors.deepBlue : AppColors.surfaceBorderLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? AppColors.surfaceBorderDark
                    : AppColors.surfaceBorderLight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  color: isDark ? AppColors.neonLime : AppColors.accentLight,
                ),
                const SizedBox(height: 4),
                Text(
                  'Add Photo',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
