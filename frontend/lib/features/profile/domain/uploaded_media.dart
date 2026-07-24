enum UploadedMediaSource {
  forum,
  ai;

  static UploadedMediaSource? tryParse(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'forum':
      case 'forum_post_media':
        return UploadedMediaSource.forum;
      case 'ai':
        return UploadedMediaSource.ai;
      default:
        return null;
    }
  }
}

class UploadedMediaItem {
  const UploadedMediaItem({
    required this.id,
    required this.source,
    required this.createdAt,
    this.url,
    this.postId,
    this.postHasText = false,
  });

  final String id;
  final UploadedMediaSource source;
  final String? url;
  final DateTime createdAt;
  final String? postId;
  final bool postHasText;

  factory UploadedMediaItem.fromJson(Map<String, dynamic> row) {
    final String id = _stringValue(row['id_media'] ?? row['mediaId']);
    final UploadedMediaSource? source = UploadedMediaSource.tryParse(
      row['source'] ?? 'forum',
    );
    final String createdAt = _stringValue(
      row['created_at'] ?? row['createdAt'],
    );
    if (id.isEmpty || source == null || createdAt.isEmpty) {
      throw const FormatException('Invalid uploaded media item.');
    }

    return UploadedMediaItem(
      id: id,
      source: source,
      url: _nullableString(row['url'] ?? row['imageUrl']),
      createdAt: DateTime.parse(createdAt),
      postId: _nullableString(row['id_post'] ?? row['postId']),
      postHasText: row['post_has_text'] == true || row['postHasText'] == true,
    );
  }
}

enum UploadedMediaDeleteStatus {
  deleted,
  failed,
  notFound;

  static UploadedMediaDeleteStatus parse(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'deleted':
        return UploadedMediaDeleteStatus.deleted;
      case 'not_found':
      case 'not-found':
      case 'notfound':
        return UploadedMediaDeleteStatus.notFound;
      case 'failed':
      default:
        return UploadedMediaDeleteStatus.failed;
    }
  }
}

class UploadedMediaDeleteResult {
  const UploadedMediaDeleteResult({
    required this.mediaId,
    required this.status,
    this.message,
  });

  final String mediaId;
  final UploadedMediaDeleteStatus status;
  final String? message;

  bool get isRetryable => status == UploadedMediaDeleteStatus.failed;

  factory UploadedMediaDeleteResult.fromJson(Map<String, dynamic> row) {
    final String mediaId = _stringValue(row['mediaId'] ?? row['id_media']);
    if (mediaId.isEmpty) {
      throw const FormatException('Invalid uploaded media delete result.');
    }

    return UploadedMediaDeleteResult(
      mediaId: mediaId,
      status: UploadedMediaDeleteStatus.parse(row['status']),
      message: _nullableString(row['message']),
    );
  }
}

class UploadedMediaDeleteSummary {
  UploadedMediaDeleteSummary(Iterable<UploadedMediaDeleteResult> results)
    : results = List<UploadedMediaDeleteResult>.unmodifiable(results);

  final List<UploadedMediaDeleteResult> results;

  List<String> get failedMediaIds => results
      .where((UploadedMediaDeleteResult result) => result.isRetryable)
      .map((UploadedMediaDeleteResult result) => result.mediaId)
      .toList(growable: false);

  bool get hasFailures => failedMediaIds.isNotEmpty;
}

String _stringValue(Object? value) => value?.toString().trim() ?? '';

String? _nullableString(Object? value) {
  final String result = _stringValue(value);
  return result.isEmpty ? null : result;
}
