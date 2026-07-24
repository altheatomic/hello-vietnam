import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_chat/domain/ai_chat_models.dart';

void main() {
  group('AiChatMessage', () {
    test('parses nullable action and normalizes timestamps to UTC', () {
      final AiChatMessage message = AiChatMessage.fromJson(<String, Object?>{
        'id_message': 'message-1',
        'id_conversation': 'conversation-1',
        'role': 'assistant',
        'content': 'Visit Hue.',
        'request_id': null,
        'created_at': '2026-07-25T08:00:00+07:00',
      });

      expect(message.action, isNull);
      expect(message.createdAt, DateTime.utc(2026, 7, 25, 1));
    });

    test('parses an allowlisted action without adding a route', () {
      final AiChatMessage message = AiChatMessage.fromJson(<String, Object?>{
        'id_message': 'message-1',
        'id_conversation': 'conversation-1',
        'role': 'assistant',
        'content': 'Build an itinerary.',
        'request_id': 'request-1',
        'created_at': '2026-07-25T01:00:00Z',
        'action': <String, Object?>{
          'key': 'trip_planner',
          'payload': <String, Object?>{'destination': 'Hue'},
        },
      });

      expect(message.action?.key, 'trip_planner');
      expect(message.action?.payload, <String, Object?>{'destination': 'Hue'});
    });

    test('rejects malformed payloads', () {
      expect(
        () => AiChatMessage.fromJson(<String, Object?>{
          'id_message': '',
          'id_conversation': 'conversation-1',
          'role': 'system',
          'content': '',
          'created_at': 'not-a-date',
        }),
        throwsFormatException,
      );
    });
  });

  test('conversation page accepts a missing cursor and sorts newest first', () {
    final AiChatConversationPage page = AiChatConversationPage.fromJson(
      <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id_conversation': 'older',
            'title': 'Older',
            'created_at': '2026-07-24T01:00:00Z',
            'updated_at': '2026-07-24T01:00:00Z',
          },
          <String, Object?>{
            'id_conversation': 'newer',
            'title': 'Newer',
            'created_at': '2026-07-25T01:00:00Z',
            'updated_at': '2026-07-25T01:00:00Z',
          },
        ],
      },
    );

    expect(page.nextCursor, isNull);
    expect(page.items.map((item) => item.id), <String>['newer', 'older']);
  });

  test('message page sorts messages chronologically', () {
    final AiChatMessagePage page = AiChatMessagePage.fromJson(<String, Object?>{
      'items': <Object?>[
        _messageJson(id: 'newer', createdAt: '2026-07-25T02:00:00Z'),
        _messageJson(id: 'older', createdAt: '2026-07-25T01:00:00Z'),
      ],
      'next_cursor': 'cursor-2',
    });

    expect(page.nextCursor, 'cursor-2');
    expect(page.items.map((item) => item.id), <String>['older', 'newer']);
  });
}

Map<String, Object?> _messageJson({
  required String id,
  required String createdAt,
}) {
  return <String, Object?>{
    'id_message': id,
    'id_conversation': 'conversation-1',
    'role': 'user',
    'content': id,
    'request_id': 'request-1',
    'created_at': createdAt,
  };
}
