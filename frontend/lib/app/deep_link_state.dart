import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../core/config/app_identity.dart';
import '../core/config/env.dart';

class DeepLinkState extends ChangeNotifier {
  DeepLinkState._();

  static final DeepLinkState instance = DeepLinkState._();

  bool _shouldNavigateToForgotPassword = false;
  String? _pendingUpgradePaymentLocation;

  void handle(Uri uri) {
    final String link = uri.toString();
    debugPrint('Handling deep link: $link');

    if (link.contains('type=recovery')) {
      _shouldNavigateToForgotPassword = true;
      debugPrint(
        'Password reset link detected - will navigate to forgot password page',
      );
      notifyListeners();
      return;
    }

    final String? paymentLocation = appRouteLocationFromDeepLink(uri);
    if (paymentLocation != null) {
      _pendingUpgradePaymentLocation = paymentLocation;
      debugPrint('App link detected - will navigate to its destination');
      notifyListeners();
    }
  }

  bool consumeForgotPasswordNavigation() {
    final bool shouldNavigate = _shouldNavigateToForgotPassword;
    _shouldNavigateToForgotPassword = false;
    return shouldNavigate;
  }

  String? consumeUpgradePaymentLocation() {
    final String? location = _pendingUpgradePaymentLocation;
    _pendingUpgradePaymentLocation = null;
    return location;
  }
}

String? appRouteLocationFromDeepLink(Uri uri, {Set<String>? shareHosts}) {
  final Set<String> trustedShareHosts =
      shareHosts ??
      <String>{if (Env.shareWebHost.trim().isNotEmpty) Env.shareWebHost.trim()};
  final bool isSharedTripLink =
      uri.scheme == 'https' &&
      trustedShareHosts.contains(uri.host) &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'trip' &&
      uri.pathSegments.last.trim().isNotEmpty;
  if (isSharedTripLink) {
    return Uri(
      path: '/shared-trip',
      queryParameters: <String, String>{'token': uri.pathSegments.last},
    ).toString();
  }

  final bool isAppLink = uri.scheme == AppIdentity.androidUrlScheme;
  if (!isAppLink) return null;

  final bool isSharedTripFallback =
      uri.host == 'shared-trip' ||
      uri.path == '/shared-trip' ||
      uri.path == '/shared-trip/';
  final String? shareToken = uri.queryParameters['token']?.trim();
  if (isSharedTripFallback && shareToken != null && shareToken.isNotEmpty) {
    return Uri(
      path: '/shared-trip',
      queryParameters: <String, String>{'token': shareToken},
    ).toString();
  }

  final bool isUpgradePayment =
      uri.host == 'upgrade-payment' ||
      uri.path == '/upgrade-payment' ||
      uri.path == '/upgrade-payment/';
  if (!isUpgradePayment) return null;

  final String query = uri.query;
  return query.isEmpty ? '/upgrade-payment' : '/upgrade-payment?$query';
}

Future<void> initDeepLinks() async {
  final appLinks = AppLinks();

  try {
    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) {
      DeepLinkState.instance.handle(initialLink);
    }
  } catch (e) {
    debugPrint('Error getting initial link: $e');
  }

  appLinks.uriLinkStream.listen(
    (Uri? uri) {
      if (uri != null) {
        DeepLinkState.instance.handle(uri);
      }
    },
    onError: (Object err) {
      debugPrint('Error listening to link stream: $err');
    },
  );
}

bool shouldNavigateToForgotPassword() {
  return DeepLinkState.instance.consumeForgotPasswordNavigation();
}

String? consumeUpgradePaymentDeepLink() {
  return DeepLinkState.instance.consumeUpgradePaymentLocation();
}
