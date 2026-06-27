import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui'; // Required for PlatformDispatcher
import 'app.dart'; // Import Prompt Generator entry point

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Globally catch and suppress unhandled Supabase deep link verifier exceptions
  PlatformDispatcher.instance.onError = (error, stack) {
    final errStr = error.toString();
    if (errStr.contains('Code verifier') || errStr.contains('AuthException')) {
      debugPrint('Suppressed async AuthException: $errStr');
      return true; // Handled and suppressed
    }
    return false; // Pass through other errors
  };

  await Supabase.initialize(
    url: 'https://patnfokhlsqejrziosjz.supabase.co',
    publishableKey: 'sb_publishable_r475q_J8YvI7mkQGr6vaYQ_HILgFIAq',
  );
  runApp(const MyApp());
}
