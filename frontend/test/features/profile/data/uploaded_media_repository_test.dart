import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/profile/data/uploaded_media_repository.dart';
import 'package:hellovietnam/features/profile/domain/uploaded_media.dart';

void main() {
  test('maps forum media rows including post text status', () async {
    Object? capturedBody;
    final UploadedMediaRepository repository = UploadedMediaRepositoryImpl(
      functionClient: SupabaseFunctionClient(
        accessTokenProvider: () async => 'test-token',
        invoker:
            (String functionName, {Map<String, String>? headers, Object? body}) async {
              expect(functionName, Env.manageUploadedMediaFunction);
              capturedBody = body;
              return <String, Object?>{
                'items': <Object?>[
                  <String, Object?>{
                    'id_media': 'media-1',
                    'source': 'forum',
                    'id_post': 'post-1',
                    'url': 'https://example.com/image.jpg',
                    'created_at': '2026-07-22T10:00:00Z',
                    'post_has_text': true,
                  },
                ],
              };
            },
      ),
    );

    final List<UploadedMediaItem> items = await repository.loadOwnedMedia();

    expect(capturedBody, <String, Object?>{'action': 'list'});
    expect(items.single.id, 'media-1');
    expect(items.single.source, UploadedMediaSource.forum);
    expect(items.single.postId, 'post-1');
    expect(items.single.url, 'https://example.com/image.jpg');
    expect(items.single.createdAt, DateTime.parse('2026-07-22T10:00:00Z'));
    expect(items.single.postHasText, isTrue);
  });

  test('maps future AI media without fabricating it during an empty listing', () async {
    final UploadedMediaRepository repository = UploadedMediaRepositoryImpl(
      functionClient: SupabaseFunctionClient(
        accessTokenProvider: () async => 'test-token',
        invoker:
            (String functionName, {Map<String, String>? headers, Object? body}) async =>
                <String, Object?>{
                  'items': <Object?>[
                    <String, Object?>{
                      'id_media': 'ai-1',
                      'source': 'ai',
                      'url': 'https://example.com/ai.jpg',
                      'created_at': '2026-07-22T11:00:00Z',
                    },
                  ],
                },
      ),
    );

    final List<UploadedMediaItem> items = await repository.loadOwnedMedia();

    expect(items.single.source, UploadedMediaSource.ai);
    expect(items.single.postId, isNull);
    expect(items.single.postHasText, isFalse);
  });

  test('keeps an empty current listing empty without fabricating AI media', () async {
    final UploadedMediaRepository repository = UploadedMediaRepositoryImpl(
      functionClient: SupabaseFunctionClient(
        accessTokenProvider: () async => 'test-token',
        invoker:
            (String functionName, {Map<String, String>? headers, Object? body}) async =>
                <String, Object?>{'items': <Object?>[]},
      ),
    );

    final List<UploadedMediaItem> items = await repository.loadOwnedMedia();

    expect(items, isEmpty);
  });

  test('skips malformed media rows while retaining valid rows', () async {
    final UploadedMediaRepository repository = UploadedMediaRepositoryImpl(
      functionClient: SupabaseFunctionClient(
        accessTokenProvider: () async => 'test-token',
        invoker:
            (String functionName, {Map<String, String>? headers, Object? body}) async =>
                <String, Object?>{
                  'items': <Object?>[
                    <String, Object?>{
                      'id_media': 'invalid-date',
                      'source': 'forum',
                      'created_at': 'not-a-date',
                    },
                    <String, Object?>{
                      'id_media': 'valid-media',
                      'source': 'forum',
                      'created_at': '2026-07-22T10:00:00Z',
                    },
                  ],
                },
      ),
    );

    final List<UploadedMediaItem> items = await repository.loadOwnedMedia();

    expect(items.map((UploadedMediaItem item) => item.id), <String>['valid-media']);
  });

  test('returns mixed delete results and retryable failed ids', () async {
    Object? capturedBody;
    final UploadedMediaRepository repository = UploadedMediaRepositoryImpl(
      functionClient: SupabaseFunctionClient(
        accessTokenProvider: () async => 'test-token',
        invoker:
            (String functionName, {Map<String, String>? headers, Object? body}) async {
              capturedBody = body;
              return <String, Object?>{
                'results': <Object?>[
                  <String, Object?>{
                    'mediaId': 'media-1',
                    'status': 'deleted',
                  },
                  <String, Object?>{
                    'mediaId': 'media-2',
                    'status': 'failed',
                    'message': 'Storage cleanup failed',
                  },
                  <String, Object?>{
                    'mediaId': 'media-3',
                    'status': 'not_found',
                  },
                ],
              };
            },
      ),
    );

    final UploadedMediaDeleteSummary summary = await repository.deleteMedia(
      <String>['media-1', 'media-2', 'media-3'],
    );

    expect(capturedBody, <String, Object?>{
      'action': 'delete',
      'mediaIds': <String>['media-1', 'media-2', 'media-3'],
    });
    expect(summary.results.map((result) => result.status), <UploadedMediaDeleteStatus>[
      UploadedMediaDeleteStatus.deleted,
      UploadedMediaDeleteStatus.failed,
      UploadedMediaDeleteStatus.notFound,
    ]);
    expect(summary.failedMediaIds, <String>['media-2']);
  });

  test('skips delete results without a media id', () async {
    final UploadedMediaRepository repository = UploadedMediaRepositoryImpl(
      functionClient: SupabaseFunctionClient(
        accessTokenProvider: () async => 'test-token',
        invoker:
            (String functionName, {Map<String, String>? headers, Object? body}) async =>
                <String, Object?>{
                  'results': <Object?>[
                    <String, Object?>{'status': 'failed'},
                    <String, Object?>{
                      'mediaId': 'media-2',
                      'status': 'failed',
                    },
                  ],
                },
      ),
    );

    final UploadedMediaDeleteSummary summary = await repository.deleteMedia(
      <String>['media-1', 'media-2'],
    );

    expect(summary.results.map((result) => result.mediaId), <String>['media-2']);
    expect(summary.failedMediaIds, <String>['media-2']);
  });

  test('copies delete results so the summary cannot be mutated', () {
    final List<UploadedMediaDeleteResult> results = <UploadedMediaDeleteResult>[
      const UploadedMediaDeleteResult(
        mediaId: 'media-1',
        status: UploadedMediaDeleteStatus.deleted,
      ),
    ];
    final UploadedMediaDeleteSummary summary = UploadedMediaDeleteSummary(results);

    results.clear();

    expect(summary.results, hasLength(1));
    expect(
      () => summary.results.add(
        const UploadedMediaDeleteResult(
          mediaId: 'media-2',
          status: UploadedMediaDeleteStatus.deleted,
        ),
      ),
      throwsUnsupportedError,
    );
  });
}
