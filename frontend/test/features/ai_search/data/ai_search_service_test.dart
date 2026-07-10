import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/features/ai_search/data/ai_search_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test(
    'analyzeImage sends image payload to the AI Search edge function',
    () async {
      http.Request? capturedRequest;
      final AiSearchService service = AiSearchService(
        client: MockClient((http.Request request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode(<String, Object?>{
              'result_type': 'food',
              'confidence': 0.91,
              'detected_name': 'Bun bo Hue',
              'summary': 'Vietnamese noodle soup',
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      final AiSearchResult result = await service.analyzeImage(
        XFile.fromData(Uint8List.fromList(<int>[1, 2, 3]), name: 'photo.png'),
      );

      expect(capturedRequest?.url.path, endsWith('/functions/v1/ai-search'));
      expect(capturedRequest?.headers['apikey'], Env.supabaseAnonKey);
      expect(
        capturedRequest?.headers['Authorization'],
        'Bearer ${Env.supabaseAnonKey}',
      );
      final Map<String, dynamic> body =
          jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['imageBase64'], base64Encode(<int>[1, 2, 3]));
      expect(body['mimeType'], 'image/jpeg');
      expect(body['fileName'], isA<String>());
      expect(result.detectedName, 'Bun bo Hue');
    },
  );
}
