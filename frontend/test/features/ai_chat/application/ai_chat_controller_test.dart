import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_chat/application/ai_chat_controller.dart';
import 'package:hellovietnam/features/ai_chat/data/ai_chat_repository.dart';
import 'package:hellovietnam/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  group('AiChatController', () {
    late _FakeRepository repository;
    late _FakeAudioPlayback audio;
    late AiChatController controller;
    int requestSequence = 0;

    setUp(() {
      repository = _FakeRepository();
      audio = _FakeAudioPlayback();
      controller = AiChatController(
        repository: repository,
        audioPlayback: audio,
        requestIdFactory: () => 'request-${++requestSequence}',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('blank messages do not call the repository', () async {
      await controller.send('   ');

      expect(repository.sendCalls, isEmpty);
      expect(controller.state.messages, isEmpty);
    });

    test(
      'optimistically adds user message and reuses request id on retry',
      () async {
        repository.sendCompleter = Completer<AiChatSendResult>();

        final Future<void> pendingSend = controller.send('Plan a Hue trip');

        expect(controller.state.messages, hasLength(1));
        expect(controller.state.messages.single.content, 'Plan a Hue trip');
        expect(controller.state.messages.single.requestId, 'request-1');
        expect(controller.state.isSending, isTrue);

        repository.sendCompleter!.completeError(Exception('offline'));
        await pendingSend;
        expect(controller.state.failedRequestIds, contains('request-1'));

        repository.sendCompleter = Completer<AiChatSendResult>();
        final Future<void> retry = controller.retryLastSend();
        expect(repository.sendCalls.map((call) => call.requestId), <String>[
          'request-1',
          'request-1',
        ]);

        repository.sendCompleter!.complete(_sendResult('request-1'));
        await retry;
        expect(controller.state.failedRequestIds, isEmpty);
        expect(controller.state.messages.map((message) => message.id), <String>[
          'user-1',
          'assistant-1',
        ]);
      },
    );

    test('failed send marks only its optimistic message', () async {
      repository.sendCompleter = Completer<AiChatSendResult>();
      final Future<void> pendingSend = controller.send('Hello');
      repository.sendCompleter!.completeError(Exception('failed'));
      await pendingSend;

      expect(controller.state.messages, hasLength(1));
      expect(
        controller.state.isMessageFailed(controller.state.messages.single),
        isTrue,
      );
    });

    test('keeps a completed exchange in question then answer order', () async {
      repository.sendCompleter = Completer<AiChatSendResult>();
      final Future<void> pendingSend = controller.send('Hello');
      final DateTime createdAt = DateTime.utc(2026, 7, 25, 10);
      repository.sendCompleter!.complete(
        AiChatSendResult(
          conversationId: 'conversation-1',
          messages: <AiChatMessage>[
            AiChatMessage(
              id: 'assistant-message',
              conversationId: 'conversation-1',
              role: AiChatRole.assistant,
              content: 'Hello! How can I help?',
              requestId: 'request-1',
              createdAt: createdAt,
            ),
            AiChatMessage(
              id: 'user-message',
              conversationId: 'conversation-1',
              role: AiChatRole.user,
              content: 'Hello',
              requestId: 'request-1',
              createdAt: createdAt,
            ),
          ],
          remaining: 99,
          idempotent: false,
        ),
      );
      await pendingSend;

      expect(controller.state.messages.map((message) => message.id), <String>[
        'user-message',
        'assistant-message',
      ]);
    });

    test('older messages prepend chronologically without duplicates', () async {
      repository.messagePages.add(
        AiChatMessagePage(
          items: <AiChatMessage>[_message('m2', 2), _message('m3', 3)],
          nextCursor: 'older',
        ),
      );
      repository.messagePages.add(
        AiChatMessagePage(
          items: <AiChatMessage>[_message('m1', 1), _message('m2', 2)],
          nextCursor: null,
        ),
      );

      await controller.loadConversation('conversation-1');
      await controller.loadOlderMessages();

      expect(controller.state.messages.map((message) => message.id), <String>[
        'm1',
        'm2',
        'm3',
      ]);
      expect(controller.state.hasMoreMessages, isFalse);
    });

    test('simultaneous pagination calls collapse to one request', () async {
      repository.messagePages.add(
        AiChatMessagePage(
          items: <AiChatMessage>[_message('m2', 2)],
          nextCursor: 'older',
        ),
      );
      await controller.loadConversation('conversation-1');

      repository.messageCompleter = Completer<AiChatMessagePage>();
      final Future<void> first = controller.loadOlderMessages();
      final Future<void> second = controller.loadOlderMessages();

      expect(repository.listMessageCalls, 2);
      repository.messageCompleter!.complete(
        AiChatMessagePage(
          items: <AiChatMessage>[_message('m1', 1)],
          nextCursor: null,
        ),
      );
      await Future.wait(<Future<void>>[first, second]);
      expect(repository.listMessageCalls, 2);
    });

    test('TTS fetches one URL per language and content pair', () async {
      await controller.playMessage(
        messageId: 'assistant-1',
        content: 'Xin chao',
        languageCode: 'vi-VN',
      );
      await controller.playMessage(
        messageId: 'assistant-1',
        content: 'Xin chao',
        languageCode: 'vi-VN',
      );

      expect(repository.ttsCalls, 1);
      expect(audio.playedUrls, <String>[
        'https://audio.test/1.mp3',
        'https://audio.test/1.mp3',
      ]);
    });

    test('dispose stops and disposes audio playback', () {
      controller.dispose();

      expect(audio.stopCalls, 1);
      expect(audio.disposeCalls, 1);
    });
  });
}

class _SendCall {
  const _SendCall(this.conversationId, this.requestId, this.content);

  final String? conversationId;
  final String requestId;
  final String content;
}

class _FakeRepository implements AiChatRepositoryContract {
  final List<_SendCall> sendCalls = <_SendCall>[];
  final List<AiChatMessagePage> messagePages = <AiChatMessagePage>[];
  Completer<AiChatSendResult>? sendCompleter;
  Completer<AiChatMessagePage>? messageCompleter;
  int listMessageCalls = 0;
  int ttsCalls = 0;

  @override
  Future<AiChatSendResult> sendMessage({
    String? conversationId,
    required String requestId,
    required String content,
  }) {
    sendCalls.add(_SendCall(conversationId, requestId, content));
    return sendCompleter?.future ??
        Future<AiChatSendResult>.value(_sendResult(requestId));
  }

  @override
  Future<AiChatMessagePage> listMessages({
    required String conversationId,
    String? cursor,
  }) {
    listMessageCalls++;
    if (messageCompleter != null) return messageCompleter!.future;
    return Future<AiChatMessagePage>.value(messagePages.removeAt(0));
  }

  @override
  Future<String> synthesizeSpeech({
    required String text,
    required String languageCode,
  }) async {
    ttsCalls++;
    return 'https://audio.test/$ttsCalls.mp3';
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
  final List<String> playedUrls = <String>[];
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> playUrl(String url) async {
    playedUrls.add(url);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

AiChatMessage _message(String id, int second) {
  return AiChatMessage(
    id: id,
    conversationId: 'conversation-1',
    role: AiChatRole.assistant,
    content: id,
    createdAt: DateTime.utc(2026, 7, 25, 10, 0, second),
  );
}

AiChatSendResult _sendResult(String requestId) {
  return AiChatSendResult(
    conversationId: 'conversation-1',
    messages: <AiChatMessage>[
      AiChatMessage(
        id: 'user-1',
        conversationId: 'conversation-1',
        role: AiChatRole.user,
        content: 'Plan a Hue trip',
        requestId: requestId,
        createdAt: DateTime.utc(2026, 7, 25, 10),
      ),
      AiChatMessage(
        id: 'assistant-1',
        conversationId: 'conversation-1',
        role: AiChatRole.assistant,
        content: 'Try the Imperial City.',
        requestId: requestId,
        createdAt: DateTime.utc(2026, 7, 25, 10, 0, 1),
      ),
    ],
    remaining: 99,
    idempotent: false,
  );
}
