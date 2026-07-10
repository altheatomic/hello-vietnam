import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/ai/ai_gateway_client.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';

void main() {
  test(
    'invoke sends ai-gateway payload through the shared function client',
    () async {
      String? capturedFunctionName;
      Object? capturedBody;
      final AiGatewayClient client = AiGatewayClient(
        functionClient: SupabaseFunctionClient(
          invoker:
              (
                String functionName, {
                Map<String, String>? headers,
                Object? body,
              }) async {
                capturedFunctionName = functionName;
                capturedBody = body;
                return <String, Object?>{
                  'feature': 'translate',
                  'provider': 'deepseek',
                  'model': 'deepseek-chat',
                  'cached': false,
                  'result': <String, Object?>{'translation': 'xin chao'},
                };
              },
        ),
      );

      final AiGatewayResponse result = await client.invoke(
        feature: 'translate',
        language: 'vi',
        input: <String, Object?>{'text': 'hello'},
        modelMode: 'fast',
      );

      expect(capturedFunctionName, 'ai-gateway');
      expect(capturedBody, <String, Object?>{
        'feature': 'translate',
        'language': 'vi',
        'input': <String, Object?>{'text': 'hello'},
        'useCache': true,
        'modelMode': 'fast',
      });
      expect(result.result['translation'], 'xin chao');
    },
  );
}
