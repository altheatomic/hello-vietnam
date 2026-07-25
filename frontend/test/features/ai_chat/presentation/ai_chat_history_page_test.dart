import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_chat/application/ai_chat_history_controller.dart';
import 'package:hellovietnam/features/ai_chat/data/ai_chat_repository.dart';
import 'package:hellovietnam/features/ai_chat/domain/ai_chat_models.dart';
import 'package:hellovietnam/features/ai_chat/presentation/ai_chat_history_page.dart';

void main() {
  testWidgets('loads conversations and opens the selected conversation', (
    tester,
  ) async {
    final _FakeHistoryRepository repository = _FakeHistoryRepository();
    final AiChatHistoryController controller = AiChatHistoryController(
      repository: repository,
    );
    addTearDown(controller.dispose);
    String? openedId;

    await tester.pumpWidget(
      MaterialApp(
        home: AiChatHistoryPage(
          controller: controller,
          onOpenConversation: (String id) => openedId = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hue weekend plan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-chat-history-open-c1')));

    expect(openedId, 'c1');
  });

  testWidgets('deletes a conversation only after confirmation', (tester) async {
    final _FakeHistoryRepository repository = _FakeHistoryRepository();
    final AiChatHistoryController controller = AiChatHistoryController(
      repository: repository,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: AiChatHistoryPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai-chat-history-delete-c1')));
    await tester.pumpAndSettle();
    expect(repository.deletedIds, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, <String>['c1']);
    expect(find.text('Hue weekend plan'), findsNothing);
  });
}

class _FakeHistoryRepository implements AiChatRepositoryContract {
  final List<String> deletedIds = <String>[];

  @override
  Future<AiChatConversationPage> listConversations({String? cursor}) async {
    return AiChatConversationPage(
      items: <AiChatConversation>[
        AiChatConversation(
          id: 'c1',
          title: 'Hue weekend plan',
          createdAt: DateTime.utc(2026, 7, 25, 8),
          updatedAt: DateTime.utc(2026, 7, 25, 9),
        ),
      ],
      nextCursor: null,
    );
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    deletedIds.add(conversationId);
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
