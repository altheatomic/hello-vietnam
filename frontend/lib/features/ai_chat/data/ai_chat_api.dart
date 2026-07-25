import '../../../core/network/supabase_function_client.dart';

abstract interface class AiChatApi {
  Future<Map<String, dynamic>> invoke(Map<String, Object?> body);
}

class SupabaseAiChatApi implements AiChatApi {
  SupabaseAiChatApi({SupabaseFunctionClient? functionClient})
    : _functionClient = functionClient ?? SupabaseFunctionClient();

  final SupabaseFunctionClient _functionClient;

  @override
  Future<Map<String, dynamic>> invoke(Map<String, Object?> body) {
    return _functionClient.invokeJson(
      'ai-chat',
      body: body,
      requireAuth: true,
      timeout: const Duration(seconds: 45),
    );
  }
}
