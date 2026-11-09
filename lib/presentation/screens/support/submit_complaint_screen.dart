import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../data/models/complaint.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/complaint_repository.dart';
import '../../widgets/widgets.dart';

class SubmitComplaintScreen extends StatefulWidget {
  final UserProfile profile;
  final String? spotId;
  final String? bookingId;

  const SubmitComplaintScreen({
    super.key,
    required this.profile,
    this.spotId,
    this.bookingId,
  });

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'Booking Issue';
  final List<String> _categories = [
    'Booking Issue',
    'Fake / Wrong Listing',
    'Owner / Host Issue',
    'Payment Dispute',
    'Content / Review Report',
    'Other',
  ];

  late Future<List<Complaint>> _complaintsFuture;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _refreshComplaints();
  }

  void _refreshComplaints() {
    setState(() {
      _complaintsFuture = ComplaintRepository.fetchUserComplaints(widget.profile.id);
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fullSubject = '[$_selectedCategory] ${_subjectController.text.trim()}';

      await ComplaintRepository.submitComplaint(
        subject: fullSubject,
        description: _descriptionController.text.trim(),
        spotId: widget.spotId,
        bookingId: widget.bookingId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted to ParkLagbee Admin team.'),
            backgroundColor: AppColors.success,
          ),
        );
        _subjectController.clear();
        _descriptionController.clear();
        _refreshComplaints();
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
        title: const Text('Help & Report Issue'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Report Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Submit a Complaint or Report',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Issue Category'),
                    items: _categories
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  if (_selectedCategory == 'Payment Dispute') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.warning),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Notice: ParkLagbee does not process, hold, or verify payments. Payment disputes must be resolved directly between customer and owner.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  ParkTextField(
                    controller: _subjectController,
                    label: 'Subject',
                    hint: 'Brief title of the issue',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter subject' : null,
                  ),
                  const SizedBox(height: 16),

                  ParkTextField(
                    controller: _descriptionController,
                    label: 'Detailed Description',
                    hint: 'Describe what happened and any steps taken...',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter description' : null,
                  ),
                  const SizedBox(height: 20),

                  ParkButton(
                    text: 'Submit Report',
                    isLoading: _isLoading,
                    onPressed: _handleSubmitComplaint,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // User's Submitted Complaints
            Text(
              'My Submitted Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<Complaint>>(
              future: _complaintsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(message: 'Loading your reports...');
                }

                final complaints = snapshot.data ?? [];

                if (complaints.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.check_circle_outline,
                    title: 'No Reports Filed',
                    description: 'You have not submitted any complaints or reports.',
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: complaints.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final c = complaints[index];
                    return ParkCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  c.subject,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c.status == 'open'
                                      ? AppColors.error.withValues(alpha: 0.15)
                                      : AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: c.status == 'open' ? AppColors.error : AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.description,
                            style: TextStyle(fontSize: 13, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateTimeUtils.formatBdDateTime(c.createdAt),
                            style: TextStyle(fontSize: 10, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
