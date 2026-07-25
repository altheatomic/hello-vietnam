import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/features/ai_search/data/ai_search_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('AI search result JSON round-trip preserves recognition data', () {
    const AiSearchResult original = AiSearchResult(
      resultType: 'food',
      confidence: 0.94,
      detectedName: 'Bun bo Hue',
      subtitle: 'Spicy beef noodle soup',
      summary: 'A central Vietnamese specialty.',
      locationHint: 'Hue',
      categoryText: 'Noodle soup',
      primaryTags: <String>['Beef', 'Noodles'],
      secondaryTags: <String>['Spicy', 'Savory'],
      bestTime: 'Breakfast',
      note: 'Contains shrimp paste.',
      culturalSignificance: 'A signature dish from Hue.',
      usageBullets: <String>['Serve hot'],
      productionMethod: 'Simmered broth',
      alternativeNames: 'Bun bo',
      priceRange: '40,000-70,000 VND',
      suggestedPlaces: <String>['Hue'],
      databaseMatch: AiSearchDatabaseMatch(
        category: 'food',
        id: 'food-1',
        name: 'Bun bo Hue',
        matchScore: 0.98,
        imagePath: 'foods/bun-bo-hue.jpg',
      ),
    );

    final AiSearchResult restored = AiSearchResult.fromJson(original.toJson());

    expect(restored.resultType, original.resultType);
    expect(restored.confidence, original.confidence);
    expect(restored.detectedName, original.detectedName);
    expect(restored.primaryTags, original.primaryTags);
    expect(restored.secondaryTags, original.secondaryTags);
    expect(restored.suggestedPlaces, original.suggestedPlaces);
    expect(restored.databaseMatch?.id, original.databaseMatch?.id);
    expect(restored.databaseMatch?.matchScore, 0.98);
    expect(
      restored.databaseMatch?.imagePath,
      original.databaseMatch?.imagePath,
    );
  });

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
              'db_match': <String, Object?>{
                'status': 'matched',
                'category': 'food',
                'id': 'food-bun-bo-hue',
                'name': 'Bún bò Huế',
                'match_score': 1,
                'image_path': 'foods/bun-bo-hue.jpg',
              },
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
      expect(result.databaseMatch?.id, 'food-bun-bo-hue');
      expect(result.databaseMatch?.name, 'Bún bò Huế');
      expect(result.databaseMatch?.category, 'food');
      expect(result.databaseMatch?.imagePath, 'foods/bun-bo-hue.jpg');
    },
  );
}
