import 'dart:convert';
import 'dart:typed_data';

import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/network/edge_function_client.dart';
import 'package:hellovietnam/features/ai_search/domain/ai_recognition_result.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

export 'package:hellovietnam/features/ai_search/domain/ai_recognition_result.dart';

class AiSearchException implements Exception {
  AiSearchException(this.message);

  final String message;

  @override
  String toString() => message;
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
