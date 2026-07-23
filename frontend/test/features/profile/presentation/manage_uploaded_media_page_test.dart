import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/profile/data/uploaded_media_repository.dart';
import 'package:hellovietnam/features/profile/domain/uploaded_media.dart';
import 'package:hellovietnam/features/profile/presentation/delete_user_data_page.dart';

void main() {
  testWidgets('lists forum media without trip choices and hides an empty AI group', (
    WidgetTester tester,
  ) async {
    final _FakeUploadedMediaRepository repository = _FakeUploadedMediaRepository(
      items: <UploadedMediaItem>[
        _forumMedia('forum-1', postId: 'post-1', postHasText: true),
      ],
    );

    await _pumpPage(tester, repository);

    expect(find.text('Manage uploaded media'), findsOneWidget);
    expect(find.text('Forum images'), findsOneWidget);
    expect(find.text('AI images'), findsNothing);
    expect(find.text('Trip 1'), findsNothing);
    expect(find.textContaining('itinerary'), findsNothing);
    expect(find.textContaining('preferences'), findsNothing);
    expect(find.text('Post includes text'), findsOneWidget);
  });

  testWidgets('opens a larger image preview popup without selecting the media', (
    WidgetTester tester,
  ) async {
    final _FakeUploadedMediaRepository repository = _FakeUploadedMediaRepository(
      items: <UploadedMediaItem>[
        _forumMedia('forum-1', postId: 'post-1', postHasText: true),
      ],
    );

    await _pumpPage(tester, repository);

    await tester.tap(find.byKey(const ValueKey<String>('media-image-forum-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('media-preview-dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('media-preview-image')), findsOneWidget);
    expect(find.text('0 selected'), findsOneWidget);
  });

  testWidgets('selects one or all media before requiring irreversible confirmation', (
    WidgetTester tester,
  ) async {
    final _FakeUploadedMediaRepository repository = _FakeUploadedMediaRepository(
      items: <UploadedMediaItem>[
        _forumMedia('forum-1', postId: 'post-1'),
        _forumMedia('forum-2', postId: 'post-2'),
        _aiMedia('ai-1'),
      ],
    );

    await _pumpPage(tester, repository);

    await tester.tap(find.byKey(const ValueKey<String>('media-forum-1')));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('select-all-media')));
    await tester.pump();
    expect(find.text('3 selected'), findsOneWidget);

    await _tapDeleteSelected(tester);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Deleting media does not delete the forum post'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Confirm media deletion'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('media-page-title')), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(repository.deleteRequests, isEmpty);
  });

  testWidgets('warns when selected media is the last image on an image-only post', (
    WidgetTester tester,
  ) async {
    final _FakeUploadedMediaRepository repository = _FakeUploadedMediaRepository(
      items: <UploadedMediaItem>[
        _forumMedia('forum-1', postId: 'image-only-post'),
      ],
    );

    await _pumpPage(tester, repository);

    await tester.tap(find.byKey(const ValueKey<String>('media-forum-1')));
    await tester.pump();
    await _tapDeleteSelected(tester);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Deleting media does not delete the forum post'),
      findsOneWidget,
    );
    expect(find.textContaining('separate action'), findsOneWidget);
  });

  testWidgets('removes successfully deleted media and leaves the forum post untouched', (
    WidgetTester tester,
  ) async {
    final _FakeUploadedMediaRepository repository = _FakeUploadedMediaRepository(
      items: <UploadedMediaItem>[
        _forumMedia('forum-1', postId: 'post-1', postHasText: true),
        _forumMedia('forum-2', postId: 'post-1', postHasText: true),
      ],
      deleteSummaries: <UploadedMediaDeleteSummary>[
        UploadedMediaDeleteSummary(<UploadedMediaDeleteResult>[
          const UploadedMediaDeleteResult(
            mediaId: 'forum-1',
            status: UploadedMediaDeleteStatus.deleted,
          ),
        ]),
      ],
    );

    await _pumpPage(tester, repository);
    await tester.tap(find.byKey(const ValueKey<String>('media-forum-1')));
    await tester.pump();
    await _tapDeleteSelected(tester);
    await tester.pumpAndSettle();
    await _tapDeleteMedia(tester);
    await tester.pumpAndSettle();

    expect(repository.deleteRequests, <List<String>>[
      <String>['forum-1'],
    ]);
    expect(find.byKey(const ValueKey<String>('media-forum-1')), findsNothing);
    expect(find.byKey(const ValueKey<String>('media-forum-2')), findsOneWidget);
    expect(find.text('Media deleted'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Media deleted'), findsNothing);
  });

  testWidgets('retains failed media and retries only the failed ids', (
    WidgetTester tester,
  ) async {
    final _FakeUploadedMediaRepository repository = _FakeUploadedMediaRepository(
      items: <UploadedMediaItem>[
        _forumMedia('forum-1', postId: 'post-1'),
        _forumMedia('forum-2', postId: 'post-2'),
      ],
      deleteSummaries: <UploadedMediaDeleteSummary>[
        UploadedMediaDeleteSummary(<UploadedMediaDeleteResult>[
          const UploadedMediaDeleteResult(
            mediaId: 'forum-1',
            status: UploadedMediaDeleteStatus.deleted,
          ),
          const UploadedMediaDeleteResult(
            mediaId: 'forum-2',
            status: UploadedMediaDeleteStatus.failed,
            message: 'Storage cleanup failed',
          ),
        ]),
        UploadedMediaDeleteSummary(<UploadedMediaDeleteResult>[
          const UploadedMediaDeleteResult(
            mediaId: 'forum-2',
            status: UploadedMediaDeleteStatus.deleted,
          ),
        ]),
      ],
    );

    await _pumpPage(tester, repository);
    await tester.tap(find.byKey(const ValueKey<String>('select-all-media')));
    await tester.pump();
    await _tapDeleteSelected(tester);
    await tester.pumpAndSettle();
    await _tapDeleteMedia(tester);
    await tester.pumpAndSettle();

    expect(find.text('Some media could not be deleted'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('media-forum-1')), findsNothing);
    expect(find.byKey(const ValueKey<String>('media-forum-2')), findsOneWidget);

    await tester.tap(find.text('Retry failed media'));
    await tester.pumpAndSettle();

    expect(repository.deleteRequests, <List<String>>[
      <String>['forum-1', 'forum-2'],
      <String>['forum-2'],
    ]);
    expect(find.text('No uploaded media yet'), findsOneWidget);
  });

  testWidgets('shows an authentication or loading error state', (
    WidgetTester tester,
  ) async {
    final _FakeUploadedMediaRepository repository = _FakeUploadedMediaRepository(
      loadError: StateError('Please sign in before using this feature.'),
    );

    await _pumpPage(tester, repository);

    expect(find.text('Unable to load uploaded media'), findsOneWidget);
    expect(find.text('Please sign in before using this feature.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('reconciles a server deletion when the delete response fails', (
    WidgetTester tester,
  ) async {
    final _FakeUploadedMediaRepository repository = _FakeUploadedMediaRepository(
      items: <UploadedMediaItem>[
        _forumMedia('forum-1', postId: 'post-1', postHasText: true),
      ],
      deleteError: StateError('response lost after server commit'),
      removeItemsBeforeDeleteError: true,
    );

    await _pumpPage(tester, repository);
    await tester.tap(find.byKey(const ValueKey<String>('media-forum-1')));
    await tester.pump();
    await _tapDeleteSelected(tester);
    await tester.pumpAndSettle();
    await _tapDeleteMedia(tester);
    await tester.pumpAndSettle();

    expect(find.text('No uploaded media yet'), findsOneWidget);
    expect(find.text('Some media could not be deleted'), findsNothing);
  });

  testWidgets('reconciles an item marked failed when it is already gone on reload', (
    WidgetTester tester,
  ) async {
    final _FakeUploadedMediaRepository repository = _FakeUploadedMediaRepository(
      items: <UploadedMediaItem>[
        _forumMedia('forum-1', postId: 'post-1', postHasText: true),
      ],
      deleteSummaries: <UploadedMediaDeleteSummary>[
        UploadedMediaDeleteSummary(<UploadedMediaDeleteResult>[
          const UploadedMediaDeleteResult(
            mediaId: 'forum-1',
            status: UploadedMediaDeleteStatus.failed,
          ),
        ]),
      ],
      removeItemsBeforeDeleteResult: true,
    );

    await _pumpPage(tester, repository);
    await tester.tap(find.byKey(const ValueKey<String>('media-forum-1')));
    await tester.pump();
    await _tapDeleteSelected(tester);
    await tester.pumpAndSettle();
    await _tapDeleteMedia(tester);
    await tester.pumpAndSettle();

    expect(find.text('No uploaded media yet'), findsOneWidget);
    expect(find.text('Some media could not be deleted'), findsNothing);
    expect(find.text('Retry failed media'), findsNothing);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  UploadedMediaRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(home: DeleteUserDataPage(repository: repository)),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapDeleteSelected(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Delete selected'),
    300,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Delete selected'));
}

Future<void> _tapDeleteMedia(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Delete media'),
    300,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Delete media'));
}

UploadedMediaItem _forumMedia(
  String id, {
  required String postId,
  bool postHasText = false,
}) {
  return UploadedMediaItem(
    id: id,
    source: UploadedMediaSource.forum,
    url: 'https://example.com/$id.jpg',
    createdAt: DateTime.utc(2026, 7, 22),
    postId: postId,
    postHasText: postHasText,
  );
}

UploadedMediaItem _aiMedia(String id) {
  return UploadedMediaItem(
    id: id,
    source: UploadedMediaSource.ai,
    url: 'https://example.com/$id.jpg',
    createdAt: DateTime.utc(2026, 7, 22),
  );
}

class _FakeUploadedMediaRepository implements UploadedMediaRepository {
  _FakeUploadedMediaRepository({
    this.items = const <UploadedMediaItem>[],
    this.deleteSummaries = const <UploadedMediaDeleteSummary>[],
    this.loadError,
    this.deleteError,
    this.removeItemsBeforeDeleteError = false,
    this.removeItemsBeforeDeleteResult = false,
  });

  final List<UploadedMediaItem> items;
  final List<UploadedMediaDeleteSummary> deleteSummaries;
  final Object? loadError;
  final Object? deleteError;
  final bool removeItemsBeforeDeleteError;
  final bool removeItemsBeforeDeleteResult;
  final List<List<String>> deleteRequests = <List<String>>[];
  int _deleteIndex = 0;

  @override
  Future<List<UploadedMediaItem>> loadOwnedMedia() async {
    if (loadError != null) throw loadError!;
    return List<UploadedMediaItem>.of(items);
  }

  @override
  Future<UploadedMediaDeleteSummary> deleteMedia(Iterable<String> mediaIds) async {
    final List<String> ids = List<String>.of(mediaIds);
    deleteRequests.add(ids);
    if (deleteError != null) {
      if (removeItemsBeforeDeleteError) {
        items.removeWhere((UploadedMediaItem item) => ids.contains(item.id));
      }
      throw deleteError!;
    }
    final UploadedMediaDeleteSummary summary = deleteSummaries[_deleteIndex++];
    if (removeItemsBeforeDeleteResult) {
      final Set<String> successfulIds = summary.results
          .where((UploadedMediaDeleteResult result) =>
              result.status == UploadedMediaDeleteStatus.failed)
          .map((UploadedMediaDeleteResult result) => result.mediaId)
          .toSet();
      items.removeWhere((UploadedMediaItem item) => successfulIds.contains(item.id));
    }
    return summary;
  }
}
