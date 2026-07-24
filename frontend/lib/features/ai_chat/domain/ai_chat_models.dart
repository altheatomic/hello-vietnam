enum AiChatRole { user, assistant }

class AiChatSuggestedAction {
  const AiChatSuggestedAction({required this.key, required this.payload});

  final String key;
  final Map<String, Object?> payload;

  factory AiChatSuggestedAction.fromJson(Map<String, dynamic> json) {
    final String key = _requiredString(json, 'key');
    final Object? rawPayload = json['payload'];
    if (rawPayload is! Map) {
      throw const FormatException('AI chat action payload must be an object.');
    }
    return AiChatSuggestedAction(
      key: key,
      payload: Map<String, Object?>.unmodifiable(
        rawPayload.map(
          (Object? key, Object? value) => MapEntry(key.toString(), value),
        ),
      ),
    );
  }
}

class AiChatConversation {
  const AiChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AiChatConversation.fromJson(Map<String, dynamic> json) {
    return AiChatConversation(
      id: _requiredString(json, 'id_conversation'),
      title: _requiredString(json, 'title'),
      createdAt: _requiredDateTime(json, 'created_at'),
      updatedAt: _requiredDateTime(json, 'updated_at'),
    );
  }
}

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.requestId,
    this.action,
  });

  final String id;
  final String conversationId;
  final AiChatRole role;
  final String content;
  final DateTime createdAt;
  final String? requestId;
  final AiChatSuggestedAction? action;

  bool get isUser => role == AiChatRole.user;

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    final String rawRole = _requiredString(json, 'role');
    final AiChatRole role = switch (rawRole) {
      'user' => AiChatRole.user,
      'assistant' => AiChatRole.assistant,
      _ => throw const FormatException('Invalid AI chat message role.'),
    };
    final Object? rawAction = json['action'];
    if (rawAction != null && rawAction is! Map) {
      throw const FormatException('AI chat message action must be an object.');
    }
    final Map<String, dynamic>? actionJson = rawAction is Map
        ? Map<String, dynamic>.from(rawAction)
        : null;

    return AiChatMessage(
      id: _requiredString(json, 'id_message'),
      conversationId: _requiredString(json, 'id_conversation'),
      role: role,
      content: _requiredString(json, 'content'),
      requestId: _optionalString(json['request_id']),
      createdAt: _requiredDateTime(json, 'created_at'),
      action: actionJson == null
          ? null
          : AiChatSuggestedAction.fromJson(actionJson),
    );
  }
}

class AiChatConversationPage {
  const AiChatConversationPage({required this.items, required this.nextCursor});

  final List<AiChatConversation> items;
  final String? nextCursor;

  factory AiChatConversationPage.fromJson(Map<String, dynamic> json) {
    final List<AiChatConversation> items =
        _objectList(
          json,
          'items',
        ).map(AiChatConversation.fromJson).toList(growable: false)..sort(
          (AiChatConversation left, AiChatConversation right) =>
              right.updatedAt.compareTo(left.updatedAt),
        );
    return AiChatConversationPage(
      items: List<AiChatConversation>.unmodifiable(items),
      nextCursor: _optionalString(json['next_cursor']),
    );
  }
}

class AiChatMessagePage {
  const AiChatMessagePage({required this.items, required this.nextCursor});

  final List<AiChatMessage> items;
  final String? nextCursor;

  factory AiChatMessagePage.fromJson(Map<String, dynamic> json) {
    final List<AiChatMessage> items =
        _objectList(
          json,
          'items',
        ).map(AiChatMessage.fromJson).toList(growable: false)..sort(
          (AiChatMessage left, AiChatMessage right) =>
              left.createdAt.compareTo(right.createdAt),
        );
    return AiChatMessagePage(
      items: List<AiChatMessage>.unmodifiable(items),
      nextCursor: _optionalString(json['next_cursor']),
    );
  }
}

class AiChatSendResult {
  const AiChatSendResult({
    required this.conversationId,
    required this.messages,
    required this.remaining,
    required this.idempotent,
  });

  final String conversationId;
  final List<AiChatMessage> messages;
  final int remaining;
  final bool idempotent;

  factory AiChatSendResult.fromJson(Map<String, dynamic> json) {
    final Object? rawRemaining = json['remaining'];
    final Object? rawIdempotent = json['idempotent'];
    if (rawRemaining is! num || rawIdempotent is! bool) {
      throw const FormatException('Invalid AI chat send response.');
    }
    final List<AiChatMessage> messages =
        _objectList(
          json,
          'messages',
        ).map(AiChatMessage.fromJson).toList(growable: false)..sort(
          (AiChatMessage left, AiChatMessage right) =>
              left.createdAt.compareTo(right.createdAt),
        );
    return AiChatSendResult(
      conversationId: _requiredString(json, 'conversation_id'),
      messages: List<AiChatMessage>.unmodifiable(messages),
      remaining: rawRemaining.toInt(),
      idempotent: rawIdempotent,
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $key.');
  }
  return value.trim();
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Expected a string value.');
  }
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final String value = _requiredString(json, key);
  final DateTime? date = DateTime.tryParse(value);
  if (date == null) throw FormatException('Invalid $key.');
  return date.toUtc();
}

List<Map<String, dynamic>> _objectList(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! List) throw FormatException('$key must be a list.');
  return value
      .map((Object? item) {
        if (item is! Map) {
          throw FormatException('$key contains an invalid item.');
        }
        return Map<String, dynamic>.from(item);
      })
      .toList(growable: false);
}
