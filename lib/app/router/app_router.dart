import 'package:flutter/material.dart';
import '../../presentation/screens/auth/auth_gate.dart';
import '../../presentation/screens/splash/splash_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String auth = '/auth';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        auth: (context) => const AuthGate(),
      };
}
