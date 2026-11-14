import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/review.dart';
import '../../../data/repositories/review_repository.dart';
import '../../widgets/widgets.dart';

class SubmitReviewDialog extends StatefulWidget {
  final Booking booking;
  final bool isHostRatingDriver;

  const SubmitReviewDialog({
    super.key,
    required this.booking,
    this.isHostRatingDriver = false,
  });

  @override
  State<SubmitReviewDialog> createState() => _SubmitReviewDialogState();
}

class _SubmitReviewDialogState extends State<SubmitReviewDialog> {
  int _rating = 5;
  final _reviewController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final review = await ReviewRepository.submitReview(
        bookingId: widget.booking.id,
        rating: _rating,
        reviewText: _reviewController.text.trim().isNotEmpty
            ? _reviewController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop<Review>(review);
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
    final dialogTitle = widget.isHostRatingDriver
        ? 'Rate Vehicle Owner / Driver'
        : 'Rate Parking Spot & Host';
    final hintText = widget.isHostRatingDriver
        ? 'Share feedback on driver punctuality, rule compliance, behavior...'
        : 'Describe spot safety, host guidelines, location access...';

    return Dialog(
      backgroundColor: isDark ? AppColors.deepBlue : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      dialogTitle,
                      style: TextStyle(
                        fontSize: 18,
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

              // Star Rating Selector
              Wrap(
                alignment: WrapAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    icon: Icon(
                      index < _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 36,
                      color: AppColors.warning,
                    ),
                    onPressed: () {
                      setState(() => _rating = index + 1);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              ParkTextField(
                controller: _reviewController,
                label: 'Public Comment (Optional)',
                hint: hintText,
              ),
              const SizedBox(height: 24),

              ParkButton(
                text: 'Submit Rating & Review',
                isLoading: _isLoading,
                onPressed: _handleSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
