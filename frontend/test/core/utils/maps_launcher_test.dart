import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/utils/maps_launcher.dart';

void main() {
  test('builds encoded universal Google Maps restaurant search URL', () {
    final uri = buildNearbyRestaurantsUri(lat: 16.0678, lng: 108.2208);

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['query'], 'restaurants near 16.0678,108.2208');
  });

  test('validates coordinate bounds and rejects placeholder coordinates', () {
    expect(hasValidMapCoordinates(lat: 16.0, lng: 108.0), isTrue);
    expect(hasValidMapCoordinates(lat: 0.0, lng: 0.0), isFalse);
    expect(hasValidMapCoordinates(lat: double.nan, lng: 108.0), isFalse);
    expect(hasValidMapCoordinates(lat: 91.0, lng: 108.0), isFalse);
    expect(hasValidMapCoordinates(lat: 16.0, lng: 181.0), isFalse);
  });

  test('URI builder rejects invalid coordinates', () {
    expect(
      () => buildNearbyRestaurantsUri(lat: 0.0, lng: 0.0),
      throwsArgumentError,
    );
  });

  test('restaurant launcher returns false for invalid coordinates', () async {
    expect(
      await openNearbyRestaurants(lat: double.nan, lng: 108.0),
      isFalse,
    );
  });
}
