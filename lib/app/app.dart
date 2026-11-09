import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class ParkLagbeeApp extends StatelessWidget {
  const ParkLagbeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Default to 2030 Futuristic Midnight & Neon Lime Dark Theme
      initialRoute: AppRouter.splash,
      routes: AppRouter.routes,
    );
  }
}
