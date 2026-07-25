import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_chat/application/ai_chat_history_controller.dart';
import 'package:hellovietnam/features/ai_chat/data/ai_chat_repository.dart';
import 'package:hellovietnam/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  group('AiChatHistoryController', () {
    late _FakeRepository repository;
    late AiChatHistoryController controller;

    setUp(() {
      repository = _FakeRepository();
      controller = AiChatHistoryController(repository: repository);
    });

    tearDown(() {
      controller.dispose();
    });

    test('loads the first conversation page', () async {
      repository.pages.add(
        AiChatConversationPage(
          items: <AiChatConversation>[_conversation('newer', 2)],
          nextCursor: 'next-page',
        ),
      );

      await controller.load();

      expect(controller.state.conversations.single.id, 'newer');
      expect(controller.state.hasMore, isTrue);
      expect(controller.state.isLoading, isFalse);
    });

    test('load more merges conversations without duplicates', () async {
      repository.pages
        ..add(
          AiChatConversationPage(
            items: <AiChatConversation>[
              _conversation('newer', 3),
              _conversation('middle', 2),
            ],
            nextCursor: 'next-page',
          ),
        )
        ..add(
          AiChatConversationPage(
            items: <AiChatConversation>[
              _conversation('middle', 2),
              _conversation('older', 1),
            ],
            nextCursor: null,
          ),
        );

      await controller.load();
      await controller.loadMore();

      expect(controller.state.conversations.map((item) => item.id), <String>[
        'newer',
        'middle',
        'older',
      ]);
      expect(controller.state.hasMore, isFalse);
      expect(repository.cursors, <String?>[null, 'next-page']);
    });

    test('concurrent load more calls collapse into one request', () async {
      repository.pages.add(
        AiChatConversationPage(
          items: <AiChatConversation>[_conversation('newer', 2)],
          nextCursor: 'next-page',
        ),
      );
      await controller.load();

      repository.pendingPage = Completer<AiChatConversationPage>();
      final Future<void> first = controller.loadMore();
      final Future<void> second = controller.loadMore();

      expect(repository.cursors, <String?>[null, 'next-page']);
      repository.pendingPage!.complete(
        const AiChatConversationPage(
          items: <AiChatConversation>[],
          nextCursor: null,
        ),
      );
      await Future.wait(<Future<void>>[first, second]);
      expect(repository.cursors, <String?>[null, 'next-page']);
    });

    test('deletes one conversation from the loaded history', () async {
      repository.pages.add(
        AiChatConversationPage(
          items: <AiChatConversation>[
            _conversation('keep', 2),
            _conversation('delete', 1),
          ],
          nextCursor: null,
        ),
      );
      await controller.load();

      await controller.deleteConversation('delete');

      expect(controller.state.conversations.map((item) => item.id), <String>[
        'keep',
      ]);
      expect(repository.deletedIds, <String>['delete']);
    });

    test('restores conversation when deletion fails', () async {
      repository.pages.add(
        AiChatConversationPage(
          items: <AiChatConversation>[_conversation('restore', 1)],
          nextCursor: null,
        ),
      );
      repository.deleteError = Exception('offline');
      await controller.load();

      await controller.deleteConversation('restore');

      expect(controller.state.conversations.single.id, 'restore');
      expect(controller.state.errorMessage, contains('offline'));
    });
  });
}

class _FakeRepository implements AiChatRepositoryContract {
  final List<AiChatConversationPage> pages = <AiChatConversationPage>[];
  final List<String?> cursors = <String?>[];
  final List<String> deletedIds = <String>[];
  Completer<AiChatConversationPage>? pendingPage;
  Object? deleteError;

  @override
  Future<AiChatConversationPage> listConversations({String? cursor}) {
    cursors.add(cursor);
    if (pendingPage != null) return pendingPage!.future;
    return Future<AiChatConversationPage>.value(pages.removeAt(0));
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    deletedIds.add(conversationId);
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<AiChatMessagePage> listMessages({
    required String conversationId,
    String? cursor,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AiChatSendResult> sendMessage({
    String? conversationId,
    required String requestId,
    required String content,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> synthesizeSpeech({
    required String text,
    required String languageCode,
  }) {
    throw UnimplementedError();
  }
}

AiChatConversation _conversation(String id, int hour) {
  return AiChatConversation(
    id: id,
    title: 'Conversation $id',
    createdAt: DateTime.utc(2026, 7, 25, hour),
    updatedAt: DateTime.utc(2026, 7, 25, hour),
  );
}
