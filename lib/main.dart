import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase initialization deferred until actual credentials are configured: $e');
  }

  runApp(const ParkLagbeeApp());
}
