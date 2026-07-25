import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/media/media_url_resolver.dart';

void main() {
  group('MediaUrlResolver', () {
    const String baseUrl = 'https://media.example.com';

    test('keeps absolute and bundled asset URLs unchanged', () {
      expect(
        MediaUrlResolver.resolve(
          'https://cdn.example.com/images/a.jpg',
          publicBaseUrl: baseUrl,
        ),
        'https://cdn.example.com/images/a.jpg',
      );
      expect(
        MediaUrlResolver.resolve('assets/images/a.jpg', publicBaseUrl: baseUrl),
        'assets/images/a.jpg',
      );
    });

    test('turns an R2 object key into a public URL', () {
      expect(
        MediaUrlResolver.resolve(
          'explore/Da Nang/my photo.jpg',
          publicBaseUrl: baseUrl,
        ),
        'https://media.example.com/explore/Da%20Nang/my%20photo.jpg',
      );
    });

    test('decodes encoded paths before resolving them', () {
      expect(
        MediaUrlResolver.resolve(
          'explore%252Ffood%252Fbun%2520bo.jpg',
          publicBaseUrl: baseUrl,
        ),
        'https://media.example.com/explore/food/bun%20bo.jpg',
      );
    });

    test('returns an empty string for a blank value', () {
      expect(MediaUrlResolver.resolve('   ', publicBaseUrl: baseUrl), isEmpty);
    });
  });
}
