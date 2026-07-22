import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../network/supabase_function_client.dart';

class CloudflareMediaUpload {
  const CloudflareMediaUpload({required this.key, required this.url});

  final String key;
  final String url;
}

class CloudflareMediaRepository {
  CloudflareMediaRepository({
    SupabaseClient? client,
    SupabaseFunctionClient? functionClient,
  }) : _functionClient =
           functionClient ??
           SupabaseFunctionClient(client: client ?? Supabase.instance.client);

  final SupabaseFunctionClient _functionClient;

  Future<CloudflareMediaUpload> uploadBytes({
    required Uint8List bytes,
    required String folder,
    required String fileName,
    required String contentType,
  }) async {
    final Map<String, dynamic> data = await _functionClient.invokeJson(
      Env.cloudflareMediaUploadFunction,
      body: <String, dynamic>{
        'action': 'upload',
        'folder': folder,
        'fileName': fileName,
        'contentType': contentType,
        'dataBase64': base64Encode(bytes),
      },
    );

    final String? key = data['key'] as String?;
    final String? url = data['url'] as String?;
    if (key == null || key.isEmpty || url == null || url.isEmpty) {
      throw Exception('MEDIA_UPLOAD_FAILED: Invalid upload response.');
    }
    return CloudflareMediaUpload(key: key, url: url);
  }

  Future<void> deleteKeys(Iterable<String> keys) async {
    final List<String> uniqueKeys = _uniqueKeys(keys);
    if (uniqueKeys.isEmpty) return;

    try {
      await _functionClient.invokeVoid(
        Env.cloudflareMediaUploadFunction,
        body: <String, dynamic>{'action': 'delete', 'keys': uniqueKeys},
      );
    } catch (_) {
      // Media cleanup should never block profile/forum data updates.
    }
  }

  Future<void> deleteKeysStrict(Iterable<String> keys) async {
    final List<String> uniqueKeys = _uniqueKeys(keys);
    if (uniqueKeys.isEmpty) return;

    await _functionClient.invokeVoid(
      Env.cloudflareMediaUploadFunction,
      body: <String, dynamic>{'action': 'delete', 'keys': uniqueKeys},
    );
  }

  String? publicUrlForKey(String key) {
    final String baseUrl = Env.cloudflareMediaPublicBaseUrl.trim();
    final String normalizedKey = _normalizeKey(key);
    if (baseUrl.isEmpty || normalizedKey.isEmpty) return null;
    return '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/${_encodeKey(normalizedKey)}';
  }

  String? keyFromUrlOrPath(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final String trimmed = value.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return _normalizeKey(trimmed);
    }

    final String baseUrl = Env.cloudflareMediaPublicBaseUrl.trim();
    if (baseUrl.isNotEmpty) {
      final Uri? baseUri = Uri.tryParse(baseUrl);
      final Uri? mediaUri = Uri.tryParse(trimmed);
      if (baseUri != null &&
          mediaUri != null &&
          baseUri.host == mediaUri.host) {
        final String basePath = baseUri.path.replaceAll(RegExp(r'/+$'), '');
        final String mediaPath = mediaUri.path;
        if (basePath.isEmpty || mediaPath.startsWith('$basePath/')) {
          final String rawKey = basePath.isEmpty
              ? mediaPath
              : mediaPath.substring(basePath.length);
          return _normalizeKey(Uri.decodeComponent(rawKey));
        }
      }
    }

    return null;
  }

  String _normalizeKey(String key) {
    return key
        .replaceAll('\\', '/')
        .split('/')
        .where((String segment) => segment.trim().isNotEmpty)
        .join('/');
  }

  String _encodeKey(String key) {
    return key
        .split('/')
        .map((String segment) => Uri.encodeComponent(segment))
        .join('/');
  }

  List<String> _uniqueKeys(Iterable<String> keys) {
    return keys
        .map((String key) => key.trim())
        .where((String key) => key.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
