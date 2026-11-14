import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/user_profile.dart';
import '../../widgets/widgets.dart';
import '../shell/main_shell_screen.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _hasShownVerificationSnackBar = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        final authState = snapshot.data;
        final event = authState?.event;

        // 1. Password Recovery Flow: Triggered by password recovery email link
        if (event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordScreen();
        }

        // 2. Email Verification Token Callback:
        // When user lands back on the app after verifying email link,
        // Supabase emits signedIn / tokenRefreshed / userUpdated.
        if ((event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.userUpdated ||
                event == AuthChangeEvent.tokenRefreshed) &&
            !_hasShownVerificationSnackBar) {
          final user = AuthService.currentUser;
          if (user != null && user.emailConfirmedAt != null) {
            _hasShownVerificationSnackBar = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Email verified successfully! You are now logged in.',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            });
          }
        }

        final session = AuthService.currentSession;

        // 3. User is signed out -> Render Login Screen
        if (session == null) {
          return const LoginScreen();
        }

        // 4. User is signed in but email is not yet confirmed
        if (!AuthService.isEmailVerified) {
          return const EmailVerificationScreen();
        }

        // 5. User is signed in & email is verified -> Proceed to Main Application
        return FutureBuilder<UserProfile?>(
          future: AuthService.fetchUserProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: LoadingIndicator(message: 'Verifying session & profile permissions...'),
              );
            }

            final profile = profileSnapshot.data;

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
