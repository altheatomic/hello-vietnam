import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'app/app.dart';
import 'core/config/env.dart';
import 'features/personalization/data/travel_preferences_repository.dart';

// Global flag to track if we should navigate to forgot password page
bool _shouldNavigateToForgotPassword = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

  await TravelPreferencesRepository.instance.initialize();

  // Handle deep links
  _initDeepLinks();

  runApp(const App());
}

void _initDeepLinks() async {
  final appLinks = AppLinks();

  // Handle initial link when app is launched from a deep link
  try {
    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink.toString());
    }
  } catch (e) {
    debugPrint('Error getting initial link: $e');
  }

  // Handle incoming links while app is running
  appLinks.uriLinkStream.listen(
    (Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri.toString());
      }
    },
    onError: (err) {
      debugPrint('Error listening to link stream: $err');
    },
  );
}

void _handleDeepLink(String link) {
  debugPrint('Handling deep link: $link');

  // Check if it's a password reset link
  if (link.contains('type=recovery')) {
    _shouldNavigateToForgotPassword = true;
    debugPrint(
      'Password reset link detected - will navigate to forgot password page',
    );
  }
}

// Function to check and clear the navigation flag
bool shouldNavigateToForgotPassword() {
  final shouldNavigate = _shouldNavigateToForgotPassword;
  _shouldNavigateToForgotPassword = false; // Clear the flag
  return shouldNavigate;
}

final supabase = Supabase.instance.client;
