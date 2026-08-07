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
}
