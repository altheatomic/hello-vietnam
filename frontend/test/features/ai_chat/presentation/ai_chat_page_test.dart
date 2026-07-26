import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/features/ai_chat/application/ai_chat_controller.dart';
import 'package:hellovietnam/features/ai_chat/data/ai_chat_repository.dart';
import 'package:hellovietnam/features/ai_chat/domain/ai_chat_models.dart';
import 'package:hellovietnam/features/ai_chat/presentation/ai_chat_page.dart';
import 'package:hellovietnam/features/profile/application/premium_entitlement_controller.dart';
import 'package:hellovietnam/features/profile/data/subscription_repository.dart';

void main() {
  testWidgets('shows Premium gate and keeps history accessible', (
    tester,
  ) async {
    var upgradeCalls = 0;
    var historyCalls = 0;
    final PremiumEntitlementController entitlement =
        await _entitlementController(active: false);
    addTearDown(entitlement.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AiChatPage(
          entitlementController: entitlement,
          onUpgrade: () => upgradeCalls++,
          onOpenHistory: () => historyCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Premium travel assistant'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-chat-upgrade')));
    await tester.tap(find.byKey(const Key('ai-chat-history')));

    expect(upgradeCalls, 1);
    expect(historyCalls, 1);
    expect(find.byKey(const Key('ai-chat-composer')), findsNothing);
  });

  testWidgets('shows retry instead of Premium gate when verification fails', (
    tester,
  ) async {
    final PremiumEntitlementController entitlement =
        PremiumEntitlementController(
          loadSubscription: () async =>
              throw const SupabaseTableException('network unavailable'),
          currentUserId: () => 'user-1',
        );
    addTearDown(entitlement.dispose);
    await entitlement.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: AiChatPage(
          entitlementController: entitlement,
          onUpgrade: () {},
          onOpenHistory: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-chat-premium-retry')), findsOneWidget);
    expect(find.text('Premium travel assistant'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('sends only after the user taps Send', (tester) async {
    final _FakeRepository repository = _FakeRepository();
    final AiChatController controller = AiChatController(
      repository: repository,
      audioPlayback: _FakeAudioPlayback(),
      requestIdFactory: () => 'request-1',
    );
    addTearDown(controller.dispose);
    final PremiumEntitlementController entitlement =
        await _entitlementController(active: true);
    addTearDown(entitlement.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AiChatPage(
          controller: controller,
          entitlementController: entitlement,
          onOpenHistory: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('ai-chat-input')),
      'Plan two days in Hue',
    );
    await tester.pump();
    expect(repository.sentContents, isEmpty);

    await tester.tap(find.byKey(const Key('ai-chat-send')));
    await tester.pumpAndSettle();

    expect(repository.sentContents, <String>['Plan two days in Hue']);
    expect(find.text('Start with the Imperial City.'), findsOneWidget);
  });

  testWidgets('opens only the suggested allowlisted action on explicit tap', (
    tester,
  ) async {
    final _FakeRepository repository = _FakeRepository()
      ..messagePage = AiChatMessagePage(
        items: <AiChatMessage>[
          _assistantMessage(
            action: const AiChatSuggestedAction(
              key: 'trip_planner',
              payload: <String, Object?>{'province': 'Hue'},
            ),
          ),
        ],
        nextCursor: null,
      );
    final AiChatController controller = AiChatController(
      repository: repository,
      audioPlayback: _FakeAudioPlayback(),
    );
    addTearDown(controller.dispose);
    final PremiumEntitlementController entitlement =
        await _entitlementController(active: true);
    addTearDown(entitlement.dispose);
    AiChatSuggestedAction? openedAction;

    await tester.pumpWidget(
      MaterialApp(
        home: AiChatPage(
          conversationId: 'conversation-1',
          controller: controller,
          entitlementController: entitlement,
          onOpenAction: (action) => openedAction = action,
          onOpenHistory: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(openedAction, isNull);
    await tester.tap(find.byKey(const Key('ai-chat-action-trip_planner')));

    expect(openedAction?.key, 'trip_planner');
  });

  testWidgets('requests speech only after speaker is tapped', (tester) async {
    final _FakeRepository repository = _FakeRepository()
      ..messagePage = AiChatMessagePage(
        items: <AiChatMessage>[_assistantMessage()],
        nextCursor: null,
      );
    final AiChatController controller = AiChatController(
      repository: repository,
      audioPlayback: _FakeAudioPlayback(),
    );
    addTearDown(controller.dispose);
    final PremiumEntitlementController entitlement =
        await _entitlementController(active: true);
    addTearDown(entitlement.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AiChatPage(
          conversationId: 'conversation-1',
          controller: controller,
          entitlementController: entitlement,
          onOpenHistory: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.ttsCalls, 0);
    await tester.tap(find.byKey(const Key('ai-chat-speak-assistant-1')));
    await tester.pumpAndSettle();

    expect(repository.ttsCalls, 1);
  });

  testWidgets('inactive user can still read an existing conversation', (
    WidgetTester tester,
  ) async {
    final PremiumEntitlementController entitlement =
        await _entitlementController(active: false);
    final _FakeRepository repository = _FakeRepository()
      ..messagePage = AiChatMessagePage(
        items: <AiChatMessage>[_assistantMessage()],
        nextCursor: null,
      );
    final AiChatController chat = AiChatController(
      repository: repository,
      audioPlayback: _FakeAudioPlayback(),
    );
    addTearDown(entitlement.dispose);
    addTearDown(chat.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AiChatPage(
          conversationId: 'conversation-1',
          controller: chat,
          entitlementController: entitlement,
          onOpenHistory: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try the Imperial City.'), findsOneWidget);
    expect(find.byKey(const Key('ai-chat-composer')), findsNothing);
  });
}

Future<PremiumEntitlementController> _entitlementController({
  required bool active,
}) async {
  final PremiumEntitlementController controller = PremiumEntitlementController(
    loadSubscription: () async => active
        ? CurrentSubscriptionInfo(
            planCode: '6m',
            planName: 'Premium 6 Months',
            durationDays: 180,
            endDate: DateTime.utc(2026, 12, 14),
          )
        : null,
    currentUserId: () => 'user-1',
  );
  await controller.refresh();
  return controller;
}

class _FakeRepository implements AiChatRepositoryContract {
  AiChatMessagePage messagePage = const AiChatMessagePage(
    items: <AiChatMessage>[],
    nextCursor: null,
  );
  final List<String> sentContents = <String>[];
  int ttsCalls = 0;

  @override
  Future<AiChatSendResult> sendMessage({
    String? conversationId,
    required String requestId,
    required String content,
  }) async {
    sentContents.add(content);
    return AiChatSendResult(
      conversationId: conversationId ?? 'conversation-1',
      messages: <AiChatMessage>[
        AiChatMessage(
          id: 'user-1',
          conversationId: conversationId ?? 'conversation-1',
          role: AiChatRole.user,
          content: content,
          requestId: requestId,
          createdAt: DateTime.utc(2026, 7, 25, 10),
        ),
        AiChatMessage(
          id: 'assistant-1',
          conversationId: conversationId ?? 'conversation-1',
          role: AiChatRole.assistant,
          content: 'Start with the Imperial City.',
          requestId: requestId,
          createdAt: DateTime.utc(2026, 7, 25, 10, 0, 1),
        ),
      ],
      remaining: 99,
      idempotent: false,
    );
  }

  @override
  Future<AiChatMessagePage> listMessages({
    required String conversationId,
    String? cursor,
  }) async {
    return messagePage;
  }

  @override
  Future<String> synthesizeSpeech({
    required String text,
    required String languageCode,
  }) async {
    ttsCalls++;
    return 'https://audio.test/message.mp3';
  }

  @override
  Future<void> deleteConversation(String conversationId) async {}

  @override
  Future<AiChatConversationPage> listConversations({String? cursor}) async {
    return const AiChatConversationPage(
      items: <AiChatConversation>[],
      nextCursor: null,
    );
  }
}

class _FakeAudioPlayback implements AiChatAudioPlayback {
  @override
  Future<void> dispose() async {}

  @override
  Future<void> playUrl(String url) async {}

  @override
  Future<void> stop() async {}
}

AiChatMessage _assistantMessage({AiChatSuggestedAction? action}) {
  return AiChatMessage(
    id: 'assistant-1',
    conversationId: 'conversation-1',
    role: AiChatRole.assistant,
    content: 'Try the Imperial City.',
    action: action,
    createdAt: DateTime.utc(2026, 7, 25, 10),
  );
}
