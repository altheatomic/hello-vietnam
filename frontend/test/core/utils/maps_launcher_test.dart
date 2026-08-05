import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/utils/maps_launcher.dart';

void main() {
  test('builds restaurant search URL from the anchor address first', () {
    final uri = buildNearbyRestaurantsUri(
      lat: 21.0241925,
      lng: 105.857823,
      placeName: 'Nhà Hát Lớn Hà Nội',
      address: '1A Tràng Tiền, Hoàn Kiếm, Hà Nội',
    );

    expect(
      uri.queryParameters['query'],
      'restaurants near Nhà Hát Lớn Hà Nội, 1A Tràng Tiền, Hoàn Kiếm, Hà Nội, Vietnam',
    );
    expect(uri.queryParameters['query'], isNot(contains('Hồ Chí Minh')));
  });

  test('falls back to the anchor name when address is unavailable', () {
    final uri = buildNearbyRestaurantsUri(
      lat: 21.0241925,
      lng: 105.857823,
      placeName: 'Nhà Hát Lớn Hà Nội',
    );

    expect(
      uri.queryParameters['query'],
      'restaurants near Nhà Hát Lớn Hà Nội, Vietnam',
    );
  });

  test('falls back to coordinates when text location is unavailable', () {
    final uri = buildNearbyRestaurantsUri(lat: 16.0678, lng: 108.2208);

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['api'], '1');
    expect(
      uri.queryParameters['query'],
      'restaurants near 16.0678,108.2208, Vietnam',
    );
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
