import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/models/user_profile.dart';
import 'tabs/bookings_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/host_tab.dart';
import 'tabs/profile_tab.dart';

class MainShellScreen extends StatefulWidget {
  final UserProfile userProfile;

  const MainShellScreen({super.key, required this.userProfile});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tabs adapted to user role
    final List<Widget> tabs = [
      HomeTab(profile: widget.userProfile),
      if (widget.userProfile.isHost || widget.userProfile.isAdmin)
        HostTab(profile: widget.userProfile),
      BookingsTab(profile: widget.userProfile),
      ProfileTab(profile: widget.userProfile),
    ];

    final List<NavigationDestination> destinations = [
      const NavigationDestination(
        icon: Icon(Icons.search_outlined),
        selectedIcon: Icon(Icons.search_rounded),
        label: 'Find Spot',
      ),
      if (widget.userProfile.isHost || widget.userProfile.isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.garage_outlined),
          selectedIcon: Icon(Icons.garage_rounded),
          label: 'My Spots',
        ),
      const NavigationDestination(
        icon: Icon(Icons.confirmation_number_outlined),
        selectedIcon: Icon(Icons.confirmation_number_rounded),
        label: 'Bookings',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: isDark ? AppColors.deepBlue : AppColors.surfaceLight,
        indicatorColor: (isDark ? AppColors.neonLime : AppColors.accentLight).withValues(alpha: 0.25),
        destinations: destinations,
      ),
    );
  }
}
