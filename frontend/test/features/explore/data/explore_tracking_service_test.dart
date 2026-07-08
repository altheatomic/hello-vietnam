import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/explore/data/explore_tracking_service.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

void main() {
  group('ExploreTrackingService', () {
    test('sends view_detail payload with mapped content type', () async {
      Map<String, String>? capturedHeaders;
      Map<String, dynamic>? capturedBody;

      final ExploreTrackingService service = ExploreTrackingService(
        functionName: 'explore',
        accessTokenProvider: () => 'token-123',
        requestIdGenerator: () => 'request-1',
        sender: ({
          Map<String, String>? headers,
          required Map<String, dynamic> body,
        }) async {
          capturedHeaders = headers;
          capturedBody = body;
        },
      );

      await service.trackViewDetail(
        category: DetailCategory.culture,
        contentId: 'culture-1',
        provinceId: 'province-9',
      );

      expect(
        capturedHeaders,
        <String, String>{'Authorization': 'Bearer token-123'},
      );
      expect(capturedBody, <String, dynamic>{
        'action': 'recordExploreEvent',
        'contentType': 'culture',
        'contentId': 'culture-1',
        'provinceId': 'province-9',
        'eventType': 'view_detail',
        'requestId': 'request-1',
      });
    });

    test('sends favorite and unfavorite events from favorite state', () async {
      final List<Map<String, dynamic>> capturedBodies = <Map<String, dynamic>>[];

      final ExploreTrackingService service = ExploreTrackingService(
        functionName: 'explore',
        accessTokenProvider: () => 'token-123',
        requestIdGenerator: () => 'request-seq',
        sender: ({
          Map<String, String>? headers,
          required Map<String, dynamic> body,
        }) async {
          capturedBodies.add(body);
        },
      );

      await service.trackFavoriteChanged(
        category: DetailCategory.food,
        contentId: 'food-1',
        provinceId: 'province-2',
        isFavorite: true,
      );
      await service.trackFavoriteChanged(
        category: DetailCategory.food,
        contentId: 'food-1',
        provinceId: 'province-2',
        isFavorite: false,
      );

      expect(capturedBodies, <Map<String, dynamic>>[
        <String, dynamic>{
          'action': 'recordExploreEvent',
          'contentType': 'food',
          'contentId': 'food-1',
          'provinceId': 'province-2',
          'eventType': 'favorite',
          'requestId': 'request-seq',
        },
        <String, dynamic>{
          'action': 'recordExploreEvent',
          'contentType': 'food',
          'contentId': 'food-1',
          'provinceId': 'province-2',
          'eventType': 'unfavorite',
          'requestId': 'request-seq',
        },
      ]);
    });

    test('sends share payload while preserving provided content type', () async {
      Map<String, dynamic>? capturedBody;

      final ExploreTrackingService service = ExploreTrackingService(
        functionName: 'explore',
        accessTokenProvider: () => 'token-789',
        requestIdGenerator: () => 'request-share',
        sender: ({
          Map<String, String>? headers,
          required Map<String, dynamic> body,
        }) async {
          capturedBody = body;
        },
      );

      await service.trackShare(
        contentType: 'poi_share',
        contentId: 'activity-7',
        provinceId: 'province-10',
      );

      expect(capturedBody, <String, dynamic>{
        'action': 'recordExploreEvent',
        'contentType': 'poi_share',
        'contentId': 'activity-7',
        'provinceId': 'province-10',
        'eventType': 'share',
        'requestId': 'request-share',
      });
    });

    test('skips sending when there is no signed-in session token', () async {
      bool wasCalled = false;

      final ExploreTrackingService service = ExploreTrackingService(
        functionName: 'explore',
        accessTokenProvider: () => null,
        requestIdGenerator: () => 'request-2',
        sender: ({
          Map<String, String>? headers,
          required Map<String, dynamic> body,
        }) async {
          wasCalled = true;
        },
      );

      await service.trackViewDetail(
        category: DetailCategory.activities,
        contentId: 'activity-1',
      );

      expect(wasCalled, isFalse);
    });

    test('swallows sender errors so tracking never breaks UX', () async {
      final ExploreTrackingService service = ExploreTrackingService(
        functionName: 'explore',
        accessTokenProvider: () => 'token-456',
        requestIdGenerator: () => 'request-3',
        sender: ({
          Map<String, String>? headers,
          required Map<String, dynamic> body,
        }) async {
          throw StateError('network failed');
        },
      );

      await expectLater(
        service.trackViewDetail(
          category: DetailCategory.localProducts,
          contentId: 'product-1',
        ),
        completes,
      );
    });
  });
}
