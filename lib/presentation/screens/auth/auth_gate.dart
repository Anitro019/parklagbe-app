import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/user_profile.dart';
import '../../widgets/widgets.dart';
import '../shell/main_shell_screen.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // Handle password recovery deep link callback
        if (snapshot.hasData && snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordScreen();
        }

        final session = AuthService.currentSession;

        // 1. User is signed out
        if (session == null) {
          return const LoginScreen();
        }

        // 2. User is signed in but email requires confirmation
        if (!AuthService.isEmailVerified) {
          return const EmailVerificationScreen();
        }

        // 3. User is signed in & verified -> Fetch server-verified profile from Supabase
        return FutureBuilder<UserProfile?>(
          future: AuthService.fetchUserProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: LoadingIndicator(message: 'Verifying session & profile permissions...'),
              );
            }

            final profile = profileSnapshot.data;

            // Fallback profile if profile row creation is still processing
            final activeProfile = profile ??
                UserProfile(
                  id: session.user.id,
                  fullName: session.user.userMetadata?['full_name'] as String? ?? 'ParkLagbee User',
                  phone: session.user.phone,
                  address: session.user.userMetadata?['address'] as String?,
                  accountType: session.user.userMetadata?['account_type'] as String? ?? 'driver',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

            return MainShellScreen(userProfile: activeProfile);
          },
        );
      },
    );
  }
}
