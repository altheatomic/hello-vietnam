import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_chat/data/ai_chat_api.dart';
import 'package:hellovietnam/features/ai_chat/data/ai_chat_repository.dart';

void main() {
  late FakeAiChatApi api;
  late AiChatRepository repository;

  setUp(() {
    api = FakeAiChatApi();
    repository = AiChatRepository(api: api);
  });

  test('sendMessage sends the exact idempotent payload', () async {
    api.response = <String, Object?>{
      'conversation_id': 'conversation-1',
      'messages': <Object?>[
        _messageJson('user-1', 'user', 'Plan a trip to Hue'),
        _messageJson('assistant-1', 'assistant', 'Start with the Citadel.'),
      ],
      'remaining': 99,
      'idempotent': false,
    };

    final result = await repository.sendMessage(
      conversationId: 'conversation-1',
      requestId: 'request-1',
      content: 'Plan a trip to Hue',
    );

    expect(api.lastBody, <String, Object?>{
      'action': 'send_message',
      'conversation_id': 'conversation-1',
      'request_id': 'request-1',
      'content': 'Plan a trip to Hue',
    });
    expect(result.conversationId, 'conversation-1');
    expect(result.remaining, 99);
    expect(result.messages, hasLength(2));
  });

  test('new conversation omits conversation_id', () async {
    api.response = <String, Object?>{
      'conversation_id': 'conversation-2',
      'messages': <Object?>[
        _messageJson('user-1', 'user', 'Hello'),
        _messageJson('assistant-1', 'assistant', 'Hi'),
      ],
      'remaining': 98,
      'idempotent': false,
    };

    await repository.sendMessage(requestId: 'request-2', content: 'Hello');

    expect(api.lastBody, <String, Object?>{
      'action': 'send_message',
      'request_id': 'request-2',
      'content': 'Hello',
    });
  });

  test('list and delete operations use scoped payloads', () async {
    api.response = <String, Object?>{'items': <Object?>[]};
    await repository.listConversations(cursor: 'conversation-cursor');
    expect(api.lastBody, <String, Object?>{
      'action': 'list_conversations',
      'cursor': 'conversation-cursor',
    });

    await repository.listMessages(
      conversationId: 'conversation-1',
      cursor: 'message-cursor',
    );
    expect(api.lastBody, <String, Object?>{
      'action': 'list_messages',
      'conversation_id': 'conversation-1',
      'cursor': 'message-cursor',
    });

    api.response = <String, Object?>{'deleted': true};
    await repository.deleteConversation('conversation-1');
    expect(api.lastBody, <String, Object?>{
      'action': 'delete_conversation',
      'conversation_id': 'conversation-1',
    });
  });

  test('synthesizeSpeech returns the audio URL', () async {
    api.response = <String, Object?>{
      'audio_url': 'https://audio.test/chat.mp3',
      'request_id': 'vbee-1',
    };

    final String url = await repository.synthesizeSpeech(
      text: 'Xin chao',
      languageCode: 'vi-VN',
    );

    expect(api.lastBody, <String, Object?>{
      'action': 'tts',
      'text': 'Xin chao',
      'language_code': 'vi-VN',
    });
    expect(url, 'https://audio.test/chat.mp3');
  });
}

class FakeAiChatApi implements AiChatApi {
  Map<String, Object?> response = <String, Object?>{};
  Map<String, Object?>? lastBody;

  @override
  Future<Map<String, dynamic>> invoke(Map<String, Object?> body) async {
    lastBody = body;
    return Map<String, dynamic>.from(response);
  }
}

Map<String, Object?> _messageJson(String id, String role, String content) {
  return <String, Object?>{
    'id_message': id,
    'id_conversation': 'conversation-1',
    'role': role,
    'content': content,
    'request_id': 'request-1',
    'created_at': '2026-07-25T01:00:00Z',
  };
}
