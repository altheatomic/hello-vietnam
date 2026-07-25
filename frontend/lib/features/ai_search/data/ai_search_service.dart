import 'dart:convert';
import 'dart:typed_data';

import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/network/edge_function_client.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AiSearchException implements Exception {
  AiSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiSearchResult {
  const AiSearchResult({
    required this.resultType,
    required this.confidence,
    required this.detectedName,
    required this.subtitle,
    required this.summary,
    required this.locationHint,
    required this.categoryText,
    required this.primaryTags,
    required this.secondaryTags,
    required this.bestTime,
    required this.note,
    required this.culturalSignificance,
    required this.usageBullets,
    required this.productionMethod,
    required this.alternativeNames,
    required this.priceRange,
    required this.suggestedPlaces,
    this.databaseMatch,
  });

  final String resultType;
  final double confidence;
  final String detectedName;
  final String subtitle;
  final String summary;
  final String locationHint;
  final String categoryText;
  final List<String> primaryTags;
  final List<String> secondaryTags;
  final String bestTime;
  final String note;
  final String culturalSignificance;
  final List<String> usageBullets;
  final String productionMethod;
  final String alternativeNames;
  final String priceRange;
  final List<String> suggestedPlaces;
  final AiSearchDatabaseMatch? databaseMatch;

  bool get isFood => resultType.toLowerCase() == 'food';

  factory AiSearchResult.fromJson(Map<String, dynamic> json) {
    List<String> readStringList(String key) {
      final Object? value = json[key];
      if (value is! List) return const <String>[];
      return value
          .map((Object? item) => item?.toString().trim() ?? '')
          .where((String item) => item.isNotEmpty)
          .toList();
    }

    return AiSearchResult(
      resultType: (json['result_type'] as String? ?? 'object').trim(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      detectedName: (json['detected_name'] as String? ?? '').trim(),
      subtitle: (json['subtitle'] as String? ?? '').trim(),
      summary: (json['summary'] as String? ?? '').trim(),
      locationHint: (json['location_hint'] as String? ?? '').trim(),
      categoryText: (json['category_text'] as String? ?? '').trim(),
      primaryTags: readStringList('primary_tags'),
      secondaryTags: readStringList('secondary_tags'),
      bestTime: (json['best_time'] as String? ?? '').trim(),
      note: (json['note'] as String? ?? '').trim(),
      culturalSignificance: (json['cultural_significance'] as String? ?? '')
          .trim(),
      usageBullets: readStringList('usage_bullets'),
      productionMethod: (json['production_method'] as String? ?? '').trim(),
      alternativeNames: (json['alternative_names'] as String? ?? '').trim(),
      priceRange: (json['price_range'] as String? ?? '').trim(),
      suggestedPlaces: readStringList('suggested_places'),
      databaseMatch: AiSearchDatabaseMatch.tryParse(json['db_match']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'result_type': resultType,
    'confidence': confidence,
    'detected_name': detectedName,
    'subtitle': subtitle,
    'summary': summary,
    'location_hint': locationHint,
    'category_text': categoryText,
    'primary_tags': primaryTags,
    'secondary_tags': secondaryTags,
    'best_time': bestTime,
    'note': note,
    'cultural_significance': culturalSignificance,
    'usage_bullets': usageBullets,
    'production_method': productionMethod,
    'alternative_names': alternativeNames,
    'price_range': priceRange,
    'suggested_places': suggestedPlaces,
    if (databaseMatch != null) 'db_match': databaseMatch!.toJson(),
  };
}

class AiSearchDatabaseMatch {
  const AiSearchDatabaseMatch({
    required this.category,
    required this.id,
    required this.name,
    required this.matchScore,
    this.imagePath,
  });

  final String category;
  final String id;
  final String name;
  final double matchScore;
  final String? imagePath;

  static AiSearchDatabaseMatch? tryParse(Object? value) {
    if (value is! Map) return null;
    final Map<String, dynamic> json = Map<String, dynamic>.from(value);
    final String status = (json['status'] as String? ?? '').trim();
    final String category = (json['category'] as String? ?? '').trim();
    final String id = (json['id'] as String? ?? '').trim();
    final String name = (json['name'] as String? ?? '').trim();
    if (status != 'matched' || category.isEmpty || id.isEmpty || name.isEmpty) {
      return null;
    }

    final String imagePath = (json['image_path'] as String? ?? '').trim();
    return AiSearchDatabaseMatch(
      category: category,
      id: id,
      name: name,
      matchScore: (json['match_score'] as num?)?.toDouble() ?? 0,
      imagePath: imagePath.isEmpty ? null : imagePath,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': 'matched',
    'category': category,
    'id': id,
    'name': name,
    'match_score': matchScore,
    if (imagePath != null) 'image_path': imagePath,
  };
}

class AiSearchService {
  AiSearchService({http.Client? client, EdgeFunctionClient? edgeFunctionClient})
    : _edgeFunctionClient =
          edgeFunctionClient ??
          EdgeFunctionClient(
            client: client,
            accessTokenProvider: () async => Env.supabaseAnonKey,
          );

  final EdgeFunctionClient _edgeFunctionClient;

  Future<AiSearchResult> analyzeImage(XFile file) async {
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw AiSearchException('Anh tai len dang rong.');
    }

    try {
      final Map<String, dynamic> data = await _edgeFunctionClient.postJson(
        'ai-search',
        requireAuth: true,
        body: <String, Object?>{
          'imageBase64': base64Encode(bytes),
          'mimeType': _inferMimeType(file),
          'fileName': file.name,
        },
      );
      return AiSearchResult.fromJson(data);
    } on EdgeFunctionException catch (error) {
      throw AiSearchException(_mapServerError(error.message));
    } on AiSearchException {
      rethrow;
    } catch (error) {
      throw AiSearchException(_mapServerError(error.toString()));
    }
  }

  String _inferMimeType(XFile file) {
    final String name = file.name.isNotEmpty ? file.name.toLowerCase() : '';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  String _mapServerError(String rawMessage) {
    final String lowerMessage = rawMessage.toLowerCase();

    if (lowerMessage.contains('missing authorization header') ||
        lowerMessage.contains('invalid jwt')) {
      return 'Supabase auth config dang sai. Hay kiem tra lai supabaseUrl va anon key.';
    }

    if (lowerMessage.contains('server is missing gemini_api_key')) {
      return 'Chua cau hinh GEMINI_API_KEY tren Supabase secrets.';
    }

    if (lowerMessage.contains('api key not valid')) {
      return 'Gemini API key khong hop le. Hay tao key moi va cap nhat Supabase secrets.';
    }

    if (lowerMessage.contains('quota') ||
        lowerMessage.contains('rate limit') ||
        lowerMessage.contains('resource has been exhausted') ||
        lowerMessage.contains('high demand')) {
      return 'Gemini dang ban hoac vuot gioi han free tier. Hay thu lai sau it phut.';
    }

    if (lowerMessage.contains('invalid json body')) {
      return 'Request AI Search gui len server khong hop le.';
    }

    return rawMessage;
  }
}
