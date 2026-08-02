import 'package:url_launcher/url_launcher.dart';

Uri buildGoogleMapsSearchQueryUri(String query) {
  final String normalized = query.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(
      query,
      'query',
      'Map search query cannot be blank.',
    );
  }
  return Uri.https('www.google.com', '/maps/search/', <String, String>{
    'api': '1',
    'query': normalized,
  });
}

Uri buildGoogleMapsDirectionsToQueryUri({
  required String query,
  double? originLat,
  double? originLng,
}) {
  final String normalized = query.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(
      query,
      'query',
      'Map destination cannot be blank.',
    );
  }
  return Uri.https('www.google.com', '/maps/dir/', <String, String>{
    'api': '1',
    if (originLat != null && originLng != null)
      'origin': '$originLat,$originLng',
    'destination': normalized,
    'travelmode': 'driving',
  });
}

Future<bool> openGoogleMapsSearchQuery(String query) async {
  return launchUrl(
    buildGoogleMapsSearchQueryUri(query),
    mode: LaunchMode.externalApplication,
  );
}

Future<bool> openGoogleMapsDirectionsToQuery({
  required String query,
  double? originLat,
  double? originLng,
}) async {
  return launchUrl(
    buildGoogleMapsDirectionsToQueryUri(
      query: query,
      originLat: originLat,
      originLng: originLng,
    ),
    mode: LaunchMode.externalApplication,
  );
}

Future<bool> openGoogleMapsDirections({
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
  List<({double lat, double lng})>? waypoints,
}) async {
  final String? waypointsParam = (waypoints != null && waypoints.isNotEmpty)
      ? waypoints.map((p) => '${p.lat},${p.lng}').join('|')
      : null;
  final Uri uri = Uri.https('www.google.com', '/maps/dir/', <String, String>{
    'api': '1',
    'origin': '$originLat,$originLng',
    'destination': '$destLat,$destLng',
    if (waypointsParam != null) 'waypoints': waypointsParam,
    'travelmode': 'driving',
  });
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> openGoogleMapsPin({
  required double lat,
  required double lng,
}) async {
  final Uri uri = Uri.https('www.google.com', '/maps/search/', <String, String>{
    'api': '1',
    'query': '$lat,$lng',
  });
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
