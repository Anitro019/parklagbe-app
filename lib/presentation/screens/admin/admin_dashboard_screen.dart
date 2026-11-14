import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../data/models/admin_audit_log.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/complaint.dart';
import '../../../data/models/parking_spot.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../widgets/widgets.dart';

class AdminDashboardScreen extends StatefulWidget {
  final UserProfile adminProfile;

  const AdminDashboardScreen({super.key, required this.adminProfile});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late Future<AdminDashboardStats> _statsFuture;
  late Future<List<ParkingSpot>> _pendingSpotsFuture;
  late Future<List<ParkingSpot>> _allSpotsFuture;
  late Future<List<UserProfile>> _usersFuture;
  late Future<List<Complaint>> _complaintsFuture;
  late Future<List<Booking>> _bookingsFuture;
  late Future<List<AdminAuditLog>> _auditLogsFuture;

  final _userSearchController = TextEditingController();
  String _spotFilter = 'pending'; // 'pending' | 'approved' | 'rejected' | ''

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _refreshAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  void _refreshAllData() {
    setState(() {
      _statsFuture = AdminRepository.fetchAdminDashboardStats();
      _pendingSpotsFuture = AdminRepository.fetchSpotsForAdmin(statusFilter: 'pending');
      _allSpotsFuture = AdminRepository.fetchSpotsForAdmin(statusFilter: _spotFilter);
      _usersFuture = AdminRepository.fetchUsersForAdmin(searchQuery: _userSearchController.text);
      _complaintsFuture = AdminRepository.fetchComplaintsForAdmin();
      _bookingsFuture = AdminRepository.fetchAllBookingsForAdmin();
      _auditLogsFuture = AdminRepository.fetchAdminAuditLogs();
    });
  }

  // Action: Moderate Parking Spot (Approve / Reject / Suspend)
  Future<void> _handleSpotModeration(ParkingSpot spot, String newStatus) async {
    String? rejectionReason;

    if (newStatus == 'rejected') {
      final reasonController = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject Listing'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please provide a reason for rejecting "${spot.title}":'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason',
                  hintText: 'e.g. Invalid address or unclear garage photos',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Reject Listing'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
      rejectionReason = reasonController.text.trim();
    }

    try {
      await AdminRepository.moderateSpot(
        adminId: widget.adminProfile.id,
        spotId: spot.id,
        newStatus: newStatus,
        reason: rejectionReason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Listing "${spot.title}" status updated to $newStatus'),
            backgroundColor: newStatus == 'approved' ? AppColors.success : AppColors.warning,
          ),
        );
        _refreshAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating spot status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Action: Resolve/Dismiss Complaint
  Future<void> _handleComplaintUpdate(Complaint complaint, String newStatus) async {
    final notesController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Complaint Status to $newStatus'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add admin resolution notes for "${complaint.subject}":'),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Admin Notes',
                hintText: 'Describe action taken...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save Resolution'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AdminRepository.updateComplaint(
        adminId: widget.adminProfile.id,
        complaintId: complaint.id,
        status: newStatus,
        adminNotes: notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Complaint updated to $newStatus'),
            backgroundColor: AppColors.success,
          ),
        );
        _refreshAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating complaint: $e'),
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'ParkLagbee Admin Panel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAllData,
            tooltip: 'Refresh Real Records',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: isDark ? AppColors.neonLime : AppColors.accentLight,
          labelColor: isDark ? AppColors.neonLime : AppColors.accentLight,
          unselectedLabelColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
            Tab(icon: Icon(Icons.approval_outlined), text: 'Spot Moderation'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Users'),
            Tab(icon: Icon(Icons.report_problem_outlined), text: 'Complaints'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Bookings'),
            Tab(icon: Icon(Icons.history_toggle_off_outlined), text: 'Audit Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(isDark),
          _buildSpotModerationTab(isDark),
          _buildUsersTab(isDark),
          _buildComplaintsTab(isDark),
          _buildBookingsTab(isDark),
          _buildAuditLogsTab(isDark),
        ],
      ),
    );
  }

  // 1. Overview Tab
  Widget _buildOverviewTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: () async => _refreshAllData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stats Grid
            FutureBuilder<AdminDashboardStats>(
              future: _statsFuture,
              builder: (context, snapshot) {
                final stats = snapshot.data;

                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.8,
                  children: [
                    _buildStatCard('Pending Approvals', '${stats?.pendingSpots ?? 0}', Icons.hourglass_top_rounded, AppColors.warning, isDark),
                    _buildStatCard('Active Spots', '${stats?.approvedSpots ?? 0}', Icons.check_circle_outline, AppColors.success, isDark),
                    _buildStatCard('Total Users', '${stats?.totalUsers ?? 0}', Icons.people_outline, isDark ? AppColors.neonCyan : AppColors.info, isDark),
                    _buildStatCard('Open Complaints', '${stats?.openComplaints ?? 0}', Icons.report_problem_outlined, AppColors.error, isDark),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Pending Approvals Quick Queue
            Text(
              'Pending Parking Spot Approvals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<ParkingSpot>>(
              future: _pendingSpotsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(message: 'Loading pending spot submissions...');
                }

                final spots = snapshot.data ?? [];

                if (spots.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.check_circle_outline,
                    title: 'All Caught Up!',
                    description: 'There are no pending parking spot submissions requiring admin review.',
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: spots.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final spot = spots[index];
                    return _buildSpotModerationCard(spot, isDark);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 2. Spot Moderation Tab
  Widget _buildSpotModerationTab(bool isDark) {
    return Column(
      children: [
        // Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('pending', 'Pending Approval', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('approved', 'Approved', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('rejected', 'Rejected', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('', 'All Spots', isDark),
              ],
            ),
          ),
        ),

        // Spot List
        Expanded(
          child: FutureBuilder<List<ParkingSpot>>(
            future: _allSpotsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingIndicator(message: 'Fetching spots...');
              }

              final spots = snapshot.data ?? [];

              if (spots.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.garage_outlined,
                  title: 'No Listings Found',
                  description: 'No parking spots match the selected status filter.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: spots.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final spot = spots[index];
                  return _buildSpotModerationCard(spot, isDark);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // 3. Users Management Tab
  Widget _buildUsersTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ParkTextField(
            controller: _userSearchController,
            label: 'Search Users by Name or Phone',
            prefixIcon: Icons.search_rounded,
            hint: 'e.g. Rahim, +8801700...',
          ),
          const SizedBox(height: 12),
          ParkButton(
            text: 'Search Users',
            type: ParkButtonType.secondary,
            onPressed: () {
              setState(() {
                _usersFuture = AdminRepository.fetchUsersForAdmin(searchQuery: _userSearchController.text);
              });
            },
          ),
          const SizedBox(height: 16),

          Expanded(
            child: FutureBuilder<List<UserProfile>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(message: 'Fetching users...');
                }

                final users = snapshot.data ?? [];

                if (users.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.person_off_outlined,
                    title: 'No Users Found',
                    description: 'No users matched your search query.',
                  );
                }

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ParkCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDark ? AppColors.neonLime : AppColors.accentLight,
                          child: Text(
                            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.midnightNavy : Colors.white,
                            ),
                          ),
                        ),
                        title: Text(
                          user.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${user.phone ?? 'No phone'} • ${user.accountType.toUpperCase()}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: user.isAdmin
                                ? AppColors.error.withValues(alpha: 0.2)
                                : (isDark ? AppColors.deepBlue : AppColors.surfaceBorderLight),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user.accountType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: user.isAdmin ? AppColors.error : (isDark ? AppColors.neonLime : AppColors.accentLight),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 4. Complaints Tab
  Widget _buildComplaintsTab(bool isDark) {
    return FutureBuilder<List<Complaint>>(
      future: _complaintsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Fetching complaints...');
        }

        final complaints = snapshot.data ?? [];

        if (complaints.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.check_circle_outline,
            title: 'No Active Complaints',
            description: 'There are no open complaints or reports submitted by users.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: complaints.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final complaint = complaints[index];
            return ParkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          complaint.subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: complaint.status == 'open'
                              ? AppColors.error.withValues(alpha: 0.2)
                              : AppColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          complaint.status.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: complaint.status == 'open' ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    complaint.description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  if (complaint.adminNotes != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Admin Resolution: ${complaint.adminNotes}',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.warning),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _handleComplaintUpdate(complaint, 'resolved'),
                        child: const Text('Resolve'),
                      ),
                      TextButton(
                        onPressed: () => _handleComplaintUpdate(complaint, 'dismissed'),
                        child: const Text('Dismiss', style: TextStyle(color: AppColors.textMutedDark)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 5. Bookings Overview Tab
  Widget _buildBookingsTab(bool isDark) {
    return FutureBuilder<List<Booking>>(
      future: _bookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Loading platform bookings...');
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.confirmation_number_outlined,
            title: 'No Platform Bookings',
            description: 'No bookings have been created on the platform yet.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return ParkCard(
              child: ListTile(
                title: Text(
                  'Ref: ${booking.bookingReference}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Type: ${booking.vehicleType.toUpperCase()} • Total: ৳${booking.totalPrice.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  booking.bookingStatus.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isDark ? AppColors.neonLime : AppColors.accentLight,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 6. Audit Logs Tab
  Widget _buildAuditLogsTab(bool isDark) {
    return FutureBuilder<List<AdminAuditLog>>(
      future: _auditLogsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Loading admin audit trail...');
        }

        final logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.history_toggle_off_outlined,
            title: 'No Audit Logs',
            description: 'No admin actions have been recorded yet.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final log = logs[index];
            return ParkCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          log.action.replaceAll('_', ' ').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark
                                ? AppColors.neonLime
                                : AppColors.accentLight,
                          ),
                        ),
                      ),
                      Text(
                        DateTimeUtils.formatBdDateTime(log.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Target: ${log.targetType} (${log.targetId})',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return ParkCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Icon(icon, size: 22, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, bool isDark) {
    final isSelected = _spotFilter == value;

    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: isDark ? AppColors.neonLime : AppColors.accentLight,
      backgroundColor: isDark ? AppColors.deepBlue : AppColors.surfaceLight,
      labelStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: isSelected ? (isDark ? AppColors.midnightNavy : Colors.white) : null,
      ),
      onSelected: (_) {
        setState(() {
          _spotFilter = value;
          _allSpotsFuture = AdminRepository.fetchSpotsForAdmin(statusFilter: _spotFilter);
        });
      },
    );
  }

  Widget _buildSpotModerationCard(ParkingSpot spot, bool isDark) {
    return ParkCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            spot.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Address: ${spot.address}, ${spot.area}, ${spot.district}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Status: ${spot.approvalStatus.toUpperCase()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: spot.approvalStatus == 'approved' ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ParkButton(
                  text: 'Approve',
                  onPressed: () => _handleSpotModeration(spot, 'approved'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ParkButton(
                  text: 'Reject',
                  type: ParkButtonType.secondary,
                  onPressed: () => _handleSpotModeration(spot, 'rejected'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
