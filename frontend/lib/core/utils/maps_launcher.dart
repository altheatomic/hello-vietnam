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
