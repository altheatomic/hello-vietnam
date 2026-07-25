import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/network/supabase_function_client.dart';
import '../domain/uploaded_media.dart';

abstract interface class UploadedMediaRepository {
  Future<List<UploadedMediaItem>> loadOwnedMedia();

  Future<UploadedMediaDeleteSummary> deleteMedia(Iterable<String> mediaIds);
}

class UploadedMediaRepositoryImpl implements UploadedMediaRepository {
  UploadedMediaRepositoryImpl({
    SupabaseClient? client,
    SupabaseFunctionClient? functionClient,
  }) : _functionClient =
           functionClient ??
           SupabaseFunctionClient(client: client ?? Supabase.instance.client);

  final SupabaseFunctionClient _functionClient;

  @override
  Future<List<UploadedMediaItem>> loadOwnedMedia() async {
    final Map<String, dynamic> data = await _functionClient.invokeJson(
      Env.manageUploadedMediaFunction,
      body: const <String, Object?>{'action': 'list'},
      requireAuth: true,
    );
    final Object? rawItems = data['items'];
    if (rawItems is! List) return const <UploadedMediaItem>[];

    final List<UploadedMediaItem> items = <UploadedMediaItem>[];
    for (final Object? rawItem in rawItems) {
      if (rawItem is! Map) continue;
      try {
        items.add(
          UploadedMediaItem.fromJson(Map<String, dynamic>.from(rawItem)),
        );
      } on FormatException {
        continue;
      }
    }
    return List<UploadedMediaItem>.unmodifiable(items);
  }

  @override
  Future<UploadedMediaDeleteSummary> deleteMedia(
    Iterable<String> mediaIds,
  ) async {
    final List<String> ids = mediaIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    final Map<String, dynamic> data = await _functionClient.invokeJson(
      Env.manageUploadedMediaFunction,
      body: <String, Object?>{'action': 'delete', 'mediaIds': ids},
      requireAuth: true,
    );
    final Object? rawResults = data['results'];
    if (rawResults is! List) {
      return UploadedMediaDeleteSummary(const <UploadedMediaDeleteResult>[]);
    }

    final List<UploadedMediaDeleteResult> results =
        <UploadedMediaDeleteResult>[];
    for (final Object? rawResult in rawResults) {
      if (rawResult is! Map) continue;
      try {
        results.add(
          UploadedMediaDeleteResult.fromJson(
            Map<String, dynamic>.from(rawResult),
          ),
        );
      } on FormatException {
        continue;
      }
    }
    return UploadedMediaDeleteSummary(results);
  }
}
