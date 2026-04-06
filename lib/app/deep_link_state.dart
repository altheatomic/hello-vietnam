import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

bool _shouldNavigateToForgotPassword = false;

Future<void> initDeepLinks() async {
  final appLinks = AppLinks();

  try {
    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink.toString());
    }
  } catch (e) {
    debugPrint('Error getting initial link: $e');
  }

  appLinks.uriLinkStream.listen(
    (Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri.toString());
      }
    },
    onError: (Object err) {
      debugPrint('Error listening to link stream: $err');
    },
  );
}

void _handleDeepLink(String link) {
  debugPrint('Handling deep link: $link');
  if (link.contains('type=recovery')) {
    _shouldNavigateToForgotPassword = true;
    debugPrint(
      'Password reset link detected - will navigate to forgot password page',
    );
  }
}

bool shouldNavigateToForgotPassword() {
  final shouldNavigate = _shouldNavigateToForgotPassword;
  _shouldNavigateToForgotPassword = false;
  return shouldNavigate;
}

