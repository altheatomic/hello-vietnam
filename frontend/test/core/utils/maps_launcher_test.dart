import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/utils/maps_launcher.dart';

void main() {
  test('search query URI preserves Vietnamese text', () {
    final Uri uri = buildGoogleMapsSearchQueryUri('Duong Nguyen Hue, Viet Nam');

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['query'], 'Duong Nguyen Hue, Viet Nam');
  });

  test('directions query omits origin when GPS is unavailable', () {
    final Uri uri = buildGoogleMapsDirectionsToQueryUri(
      query: 'Nguyen Hue Street, Vietnam',
    );

    expect(uri.queryParameters['destination'], 'Nguyen Hue Street, Vietnam');
    expect(uri.queryParameters.containsKey('origin'), isFalse);
  });

  test('query URI builders reject blank searches', () {
    expect(() => buildGoogleMapsSearchQueryUri('  '), throwsArgumentError);
    expect(
      () => buildGoogleMapsDirectionsToQueryUri(query: '  '),
      throwsArgumentError,
    );
  });

  test('nearby restaurant URI searches around the supplied coordinates', () {
    final Uri uri = buildGoogleMapsNearbyRestaurantsUri(
      lat: 21.0285,
      lng: 105.8357,
      placeName: 'Temple of Literature',
      provinceName: 'Hanoi',
    );

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(
      uri.queryParameters['query'],
      'restaurants near Temple of Literature, Hanoi, Vietnam',
    );
  });

  test('nearby restaurant geo URI keeps the exact anchor coordinates', () {
    final Uri uri = buildGoogleMapsNearbyRestaurantsGeoUri(
      lat: 21.025376,
      lng: 105.8463,
    );

    expect(uri.scheme, 'geo');
    expect(uri.path, '21.025376,105.8463');
    expect(uri.queryParameters['q'], 'restaurants');
  });

  test('nearby hotel geo URI keeps the exact anchor coordinates', () {
    final Uri uri = buildGoogleMapsNearbyHotelsGeoUri(
      lat: 21.0285,
      lng: 105.8357,
    );

    expect(uri.scheme, 'geo');
    expect(uri.path, '21.0285,105.8357');
    expect(uri.queryParameters['q'], 'hotels');
  });

  test('nearby hotel search fallback uses the exact anchor coordinates', () {
    final Uri uri = buildGoogleMapsNearbyHotelsUri(
      lat: 10.7769,
      lng: 106.7009,
    );

    expect(
      uri.queryParameters['query'],
      'hotels near 10.7769,106.7009',
    );
  });

  test('nearby restaurant URI rejects invalid coordinates', () {
    expect(
      () => buildGoogleMapsNearbyRestaurantsUri(lat: 0, lng: 0),
      throwsArgumentError,
    );
    expect(
      () => buildGoogleMapsNearbyRestaurantsUri(lat: 91, lng: 105.8357),
      throwsArgumentError,
    );
  });
}
