import '../domain/ai_chat_models.dart';
import 'ai_chat_api.dart';

class AiChatRepository {
  AiChatRepository({AiChatApi? api}) : _api = api ?? SupabaseAiChatApi();

  final AiChatApi _api;

  Future<AiChatSendResult> sendMessage({
    String? conversationId,
    required String requestId,
    required String content,
  }) async {
    final Map<String, Object?> body = <String, Object?>{
      'action': 'send_message',
      if (conversationId != null && conversationId.trim().isNotEmpty)
        'conversation_id': conversationId.trim(),
      'request_id': requestId,
      'content': content,
    };
    return AiChatSendResult.fromJson(await _api.invoke(body));
  }

  Future<AiChatConversationPage> listConversations({String? cursor}) async {
    return AiChatConversationPage.fromJson(
      await _api.invoke(<String, Object?>{
        'action': 'list_conversations',
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      }),
    );
  }

  Future<AiChatMessagePage> listMessages({
    required String conversationId,
    String? cursor,
  }) async {
    return AiChatMessagePage.fromJson(
      await _api.invoke(<String, Object?>{
        'action': 'list_messages',
        'conversation_id': conversationId,
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      }),
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    await _api.invoke(<String, Object?>{
      'action': 'delete_conversation',
      'conversation_id': conversationId,
    });
  }

  Future<String> synthesizeSpeech({
    required String text,
    required String languageCode,
  }) async {
    final Map<String, dynamic> response = await _api.invoke(<String, Object?>{
      'action': 'tts',
      'text': text,
      'language_code': languageCode,
    });
    final Object? rawUrl = response['audio_url'];
    if (rawUrl is! String || rawUrl.trim().isEmpty) {
      throw const FormatException('AI chat speech response has no audio URL.');
    }
    return rawUrl.trim();
  }
}
