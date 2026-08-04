import 'package:url_launcher/url_launcher.dart';

Future<void> openGoogleMapsDirections({
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
  List<({double lat, double lng})>? waypoints,
}) async {
  final String waypointsParam = (waypoints != null && waypoints.isNotEmpty)
      ? '&waypoints=${waypoints.map((p) => '${p.lat},${p.lng}').join('|')}'
      : '';
  final Uri uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&origin=$originLat,$originLng'
    '&destination=$destLat,$destLng'
    '$waypointsParam'
    '&travelmode=driving',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> openGoogleMapsPin({
  required double lat,
  required double lng,
}) async {
  final Uri uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

bool hasValidMapCoordinates({required double lat, required double lng}) {
  return lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      !(lat == 0.0 && lng == 0.0);
}

Uri buildNearbyRestaurantsUri({required double lat, required double lng}) {
  if (!hasValidMapCoordinates(lat: lat, lng: lng)) {
    throw ArgumentError.value(<double>[lat, lng], 'coordinates');
  }
  return Uri.https(
    'www.google.com',
    '/maps/search/',
    <String, String>{
      'api': '1',
      'query': 'restaurants near $lat,$lng',
    },
  );
}

Future<bool> openNearbyRestaurants({
  required double lat,
  required double lng,
}) async {
  if (!hasValidMapCoordinates(lat: lat, lng: lng)) return false;
  try {
    return await launchUrl(
      buildNearbyRestaurantsUri(lat: lat, lng: lng),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
