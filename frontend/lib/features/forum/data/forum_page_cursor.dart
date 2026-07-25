class ForumPageCursor {
  ForumPageCursor({required DateTime createdAt, required String id})
    : createdAt = createdAt.toUtc(),
      id = id.trim() {
    if (this.id.isEmpty) {
      throw const FormatException('Forum page cursor id is required.');
    }
  }

  factory ForumPageCursor.fromRow(
    Map<String, dynamic> row, {
    required String idKey,
  }) {
    final String rawCreatedAt = row['created_at']?.toString().trim() ?? '';
    final String id = row[idKey]?.toString().trim() ?? '';
    final DateTime? createdAt = DateTime.tryParse(rawCreatedAt);
    if (createdAt == null || id.isEmpty) {
      throw const FormatException('Invalid forum page cursor row.');
    }
    return ForumPageCursor(createdAt: createdAt, id: id);
  }

  final DateTime createdAt;
  final String id;

  Map<String, dynamic> toRpcArguments({
    required String createdAtKey,
    required String idKey,
  }) {
    return <String, dynamic>{
      createdAtKey: createdAt.toIso8601String(),
      idKey: id,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ForumPageCursor &&
            createdAt == other.createdAt &&
            id == other.id;
  }

  @override
  int get hashCode => Object.hash(createdAt, id);
}
