import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/permission_disclosures.dart';
import '../../../data/models/user_profile.dart';
import '../../widgets/widgets.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _nidController;
  late TextEditingController _licenseController;

  File? _avatarFile;
  Uint8List? _avatarBytes;

  File? _docFile;
  Uint8List? _docBytes;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _phoneController = TextEditingController(text: widget.profile.phone ?? '');
    _addressController = TextEditingController(
      text: widget.profile.address ?? '',
    );
    _nidController = TextEditingController(
      text: widget.profile.nidNumber ?? '',
    );
    _licenseController = TextEditingController(
      text: widget.profile.drivingLicenseNumber ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _nidController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (!await PermissionDisclosures.showMediaDisclosure(context)) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );

    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() => _avatarBytes = bytes);
      } else {
        setState(() => _avatarFile = File(picked.path));
      }
    }
  }

  Future<void> _pickVerificationDoc() async {
    if (!await PermissionDisclosures.showMediaDisclosure(context)) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() => _docBytes = bytes);
      } else {
        setState(() => _docFile = File(picked.path));
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.updateUserProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        nidNumber: _nidController.text.trim(),
        drivingLicenseNumber: _licenseController.text.trim(),
        avatarFile: _avatarFile,
        avatarBytes: _avatarBytes,
        docFile: _docFile,
        docBytes: _docBytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile & verification documents updated successfully!',
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

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Your Account?'),
        content: const Text(
          'This action is permanent and will delete your profile, listings, and data from ParkLagbee in accordance with privacy policies. Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AuthService.deleteAccount();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting account: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ImageProvider? newAvatarImage;
    if (kIsWeb && _avatarBytes != null) {
      newAvatarImage = MemoryImage(_avatarBytes!);
    } else if (_avatarFile != null) {
      newAvatarImage = FileImage(_avatarFile!);
    } else if (widget.profile.avatarUrl != null &&
        widget.profile.avatarUrl!.isNotEmpty) {
      newAvatarImage = NetworkImage(widget.profile.avatarUrl!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile & Identity Verification')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Avatar & Verification Badge
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: isDark
                            ? AppColors.deepBlue
                            : AppColors.surfaceBorderLight,
                        backgroundImage: newAvatarImage,
                        child: newAvatarImage == null
                            ? Text(
                                widget.profile.fullName.isNotEmpty
                                    ? widget.profile.fullName[0].toUpperCase()
                                    : 'P',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.neonLime
                                      : AppColors.accentLight,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _pickAvatar,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: isDark
                                ? AppColors.neonLime
                                : AppColors.accentLight,
                            child: Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: isDark
                                  ? AppColors.midnightNavy
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Verification Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (widget.profile.isVerified
                                  ? AppColors.success
                                  : AppColors.warning)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.profile.isVerified
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.profile.isVerified
                              ? Icons.verified
                              : Icons.verified_user_outlined,
                          size: 16,
                          color: widget.profile.isVerified
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.profile.isVerified
                              ? 'VERIFIED PROFILE'
                              : 'UNVERIFIED PROFILE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: widget.profile.isVerified
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

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

                // General Information
                Text(
                  'General Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.neonLime : AppColors.accentLight,
                  ),
                ),
                const SizedBox(height: 12),
                ParkTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  prefixIcon: Icons.person_outline,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                ParkTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                ParkTextField(
                  controller: _addressController,
                  label: 'Address / Area',
                  prefixIcon: Icons.location_on_outlined,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter address or area';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Identity & Vehicle Verification Section (Trust & Safety - Feature 5)
                Text(
                  'Trust & Verification (Feature 5)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.neonLime : AppColors.accentLight,
                  ),
                ),
                const SizedBox(height: 12),
                ParkCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ParkTextField(
                        controller: _nidController,
                        label: widget.profile.isHost
                            ? 'NID Number (Spot Owner)'
                            : 'NID Number (Optional)',
                        hint: 'e.g. 1992261024000000',
                        prefixIcon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 12),
                      ParkTextField(
                        controller: _licenseController,
                        label: widget.profile.isDriver
                            ? 'Driving License Number (Vehicle Owner)'
                            : 'Driving License Number (Optional)',
                        hint: 'e.g. DK0198273',
                        prefixIcon: Icons.credit_card_outlined,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Upload Identity Document (NID Photo / Driving License)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickVerificationDoc,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.deepBlue
                                : AppColors.surfaceBorderLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.neonLime
                                  : AppColors.accentLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.upload_file_rounded,
                                color: isDark
                                    ? AppColors.neonLime
                                    : AppColors.accentLight,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  (_docFile != null || _docBytes != null)
                                      ? 'Document Selected (Ready to Upload)'
                                      : (widget.profile.verificationDocUrl !=
                                                null
                                            ? 'Document Uploaded'
                                            : 'Tap to upload NID or Driving License Photo'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                ParkButton(
                  text: 'Save Changes & Submit Verification',
                  isLoading: _isLoading,
                  onPressed: _handleSave,
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                // Delete Account Section (Google Play Requirement)
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: _handleDeleteAccount,
                    icon: const Icon(
                      Icons.delete_forever_outlined,
                      color: AppColors.error,
                      size: 20,
                    ),
                    label: const Text(
                      'Delete My Account',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
