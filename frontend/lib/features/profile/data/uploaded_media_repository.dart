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

    return rawItems
        .whereType<Map>()
        .map(
          (Map row) => UploadedMediaItem.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .whereType<UploadedMediaItem>()
        .toList(growable: false);
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
      return const UploadedMediaDeleteSummary(
        <UploadedMediaDeleteResult>[],
      );
    }

    return UploadedMediaDeleteSummary(
      rawResults
          .whereType<Map>()
          .map(
            (Map row) => UploadedMediaDeleteResult.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false),
    );
  }
}
