import 'package:url_launcher/url_launcher.dart';

bool hasValidMapCoordinates({required double lat, required double lng}) {
  return lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      !(lat == 0 && lng == 0);
}

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

Uri buildGoogleMapsNearbyRestaurantsUri({
  required double lat,
  required double lng,
  String? placeName,
  String? provinceName,
}) {
  if (!hasValidMapCoordinates(lat: lat, lng: lng)) {
    throw ArgumentError.value(
      '$lat,$lng',
      'coordinates',
      'Map coordinates must be valid and cannot be 0,0.',
    );
  }

  final List<String> locationParts = <String>[
    if (placeName?.trim().isNotEmpty == true) placeName!.trim(),
    if (provinceName?.trim().isNotEmpty == true) provinceName!.trim(),
    'Vietnam',
  ];
  return buildGoogleMapsSearchQueryUri(
    'restaurants near ${locationParts.join(', ')}',
  );
}

Uri buildGoogleMapsNearbyRestaurantsGeoUri({
  required double lat,
  required double lng,
}) {
  if (!hasValidMapCoordinates(lat: lat, lng: lng)) {
    throw ArgumentError.value(
      '$lat,$lng',
      'coordinates',
      'Map coordinates must be valid and cannot be 0,0.',
    );
  }
  return Uri(
    scheme: 'geo',
    path: '$lat,$lng',
    queryParameters: const <String, String>{'q': 'restaurants'},
  );
}

Future<bool> openGoogleMapsNearbyRestaurants({
  required double lat,
  required double lng,
  String? placeName,
  String? provinceName,
}) async {
  final bool openedGeoUri = await launchUrl(
    buildGoogleMapsNearbyRestaurantsGeoUri(lat: lat, lng: lng),
    mode: LaunchMode.externalApplication,
  );
  if (openedGeoUri) return true;

  return launchUrl(
    buildGoogleMapsNearbyRestaurantsUri(
      lat: lat,
      lng: lng,
      placeName: placeName,
      provinceName: provinceName,
    ),
    mode: LaunchMode.externalApplication,
  );
}

Uri buildGoogleMapsNearbyHotelsUri({
  required double lat,
  required double lng,
}) {
  if (!hasValidMapCoordinates(lat: lat, lng: lng)) {
    throw ArgumentError.value(
      '$lat,$lng',
      'coordinates',
      'Map coordinates must be valid and cannot be 0,0.',
    );
  }
  return buildGoogleMapsSearchQueryUri('hotels near $lat,$lng');
}

Uri buildGoogleMapsNearbyHotelsGeoUri({
  required double lat,
  required double lng,
}) {
  if (!hasValidMapCoordinates(lat: lat, lng: lng)) {
    throw ArgumentError.value(
      '$lat,$lng',
      'coordinates',
      'Map coordinates must be valid and cannot be 0,0.',
    );
  }
  return Uri(
    scheme: 'geo',
    path: '$lat,$lng',
    queryParameters: const <String, String>{'q': 'hotels'},
  );
}

Future<bool> openGoogleMapsNearbyHotels({
  required double lat,
  required double lng,
}) async {
  final bool openedGeoUri = await launchUrl(
    buildGoogleMapsNearbyHotelsGeoUri(lat: lat, lng: lng),
    mode: LaunchMode.externalApplication,
  );
  if (openedGeoUri) return true;

  return launchUrl(
    buildGoogleMapsNearbyHotelsUri(lat: lat, lng: lng),
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
    if (waypointsParam is String) 'waypoints': waypointsParam,
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
