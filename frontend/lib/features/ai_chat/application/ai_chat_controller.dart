import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../data/ai_chat_repository.dart';
import '../domain/ai_chat_models.dart';

typedef AiChatRequestIdFactory = String Function();

abstract interface class AiChatAudioPlayback {
  Future<void> playUrl(String url);
  Future<void> stop();
  Future<void> dispose();
}

class AudioplayersAiChatPlayback implements AiChatAudioPlayback {
  AudioplayersAiChatPlayback({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> playUrl(String url) => _player.play(UrlSource(url));

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

class AiChatState {
  const AiChatState({
    this.conversationId,
    this.messages = const <AiChatMessage>[],
    this.isInitialLoading = false,
    this.isLoadingOlder = false,
    this.isSending = false,
    this.hasMoreMessages = true,
    this.nextCursor,
    this.errorMessage,
    this.remainingMessages,
    this.failedRequestIds = const <String>{},
    this.playingMessageId,
  });

  final String? conversationId;
  final List<AiChatMessage> messages;
  final bool isInitialLoading;
  final bool isLoadingOlder;
  final bool isSending;
  final bool hasMoreMessages;
  final String? nextCursor;
  final String? errorMessage;
  final int? remainingMessages;
  final Set<String> failedRequestIds;
  final String? playingMessageId;

  bool isMessageFailed(AiChatMessage message) {
    final String? requestId = message.requestId;
    return requestId != null && failedRequestIds.contains(requestId);
  }

  AiChatState copyWith({
    Object? conversationId = _unset,
    List<AiChatMessage>? messages,
    bool? isInitialLoading,
    bool? isLoadingOlder,
    bool? isSending,
    bool? hasMoreMessages,
    Object? nextCursor = _unset,
    Object? errorMessage = _unset,
    Object? remainingMessages = _unset,
    Set<String>? failedRequestIds,
    Object? playingMessageId = _unset,
  }) {
    return AiChatState(
      conversationId: identical(conversationId, _unset)
          ? this.conversationId
          : conversationId as String?,
      messages: messages ?? this.messages,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isSending: isSending ?? this.isSending,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      nextCursor: identical(nextCursor, _unset)
          ? this.nextCursor
          : nextCursor as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      remainingMessages: identical(remainingMessages, _unset)
          ? this.remainingMessages
          : remainingMessages as int?,
      failedRequestIds: failedRequestIds ?? this.failedRequestIds,
      playingMessageId: identical(playingMessageId, _unset)
          ? this.playingMessageId
          : playingMessageId as String?,
    );
  }
}

class AiChatController extends ChangeNotifier {
  AiChatController({
    AiChatRepositoryContract? repository,
    AiChatAudioPlayback? audioPlayback,
    AiChatRequestIdFactory? requestIdFactory,
  }) : _repository = repository ?? AiChatRepository(),
       _audioPlayback = audioPlayback ?? AudioplayersAiChatPlayback(),
       _requestIdFactory = requestIdFactory ?? _newUuidV4;

  final AiChatRepositoryContract _repository;
  final AiChatAudioPlayback _audioPlayback;
  final AiChatRequestIdFactory _requestIdFactory;
  final Map<String, String> _audioUrlCache = <String, String>{};

  AiChatState _state = const AiChatState();
  AiChatState get state => _state;

  String? _activeSendRequestId;
  _FailedDraft? _failedDraft;
  bool _disposed = false;

  Future<void> loadConversation(String conversationId) async {
    if (conversationId.trim().isEmpty || _state.isInitialLoading) return;
    _setState(
      AiChatState(
        conversationId: conversationId.trim(),
        isInitialLoading: true,
      ),
    );
    try {
      final AiChatMessagePage page = await _repository.listMessages(
        conversationId: conversationId.trim(),
      );
      _setState(
        _state.copyWith(
          messages: page.items,
          isInitialLoading: false,
          hasMoreMessages: page.nextCursor != null,
          nextCursor: page.nextCursor,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isInitialLoading: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> loadOlderMessages() async {
    final String? conversationId = _state.conversationId;
    if (conversationId == null ||
        _state.isInitialLoading ||
        _state.isLoadingOlder ||
        !_state.hasMoreMessages) {
      return;
    }
    _setState(_state.copyWith(isLoadingOlder: true, errorMessage: null));
    try {
      final AiChatMessagePage page = await _repository.listMessages(
        conversationId: conversationId,
        cursor: _state.nextCursor,
      );
      _setState(
        _state.copyWith(
          messages: _mergeMessages(page.items, _state.messages),
          isLoadingOlder: false,
          hasMoreMessages: page.nextCursor != null,
          nextCursor: page.nextCursor,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(isLoadingOlder: false, errorMessage: error.toString()),
      );
    }
  }

  Future<bool> send(String content) async {
    final String normalized = content.trim();
    if (normalized.isEmpty || _state.isSending) return false;
    final String requestId = _requestIdFactory();
    _activeSendRequestId = requestId;
    _failedDraft = _FailedDraft(content: normalized, requestId: requestId);

    final AiChatMessage optimistic = AiChatMessage(
      id: 'local:$requestId',
      conversationId: _state.conversationId ?? 'pending',
      role: AiChatRole.user,
      content: normalized,
      requestId: requestId,
      createdAt: DateTime.now().toUtc(),
    );
    _setState(
      _state.copyWith(
        messages: _mergeMessages(_state.messages, <AiChatMessage>[optimistic]),
        failedRequestIds: _withoutFailure(requestId),
        errorMessage: null,
      ),
    );
    return _sendDraft(_failedDraft!);
  }

  Future<void> retryLastSend() async {
    final _FailedDraft? draft = _failedDraft;
    if (draft == null || _state.isSending) return;
    _activeSendRequestId = draft.requestId;
    _setState(
      _state.copyWith(
        failedRequestIds: _withoutFailure(draft.requestId),
        errorMessage: null,
      ),
    );
    await _sendDraft(draft);
  }

  Future<bool> _sendDraft(_FailedDraft draft) async {
    _setState(_state.copyWith(isSending: true));
    try {
      final AiChatSendResult result = await _repository.sendMessage(
        conversationId: _state.conversationId,
        requestId: draft.requestId,
        content: draft.content,
      );
      if (_activeSendRequestId != draft.requestId) return false;
      final List<AiChatMessage> retained = _state.messages
          .where(
            (AiChatMessage message) =>
                message.requestId != draft.requestId ||
                !message.id.startsWith('local:'),
          )
          .toList(growable: false);
      _failedDraft = null;
      _activeSendRequestId = null;
      _setState(
        _state.copyWith(
          conversationId: result.conversationId,
          messages: _mergeMessages(retained, result.messages),
          isSending: false,
          remainingMessages: result.remaining,
          failedRequestIds: _withoutFailure(draft.requestId),
          errorMessage: null,
        ),
      );
      return true;
    } catch (error) {
      if (_activeSendRequestId != draft.requestId) return false;
      _activeSendRequestId = null;
      _setState(
        _state.copyWith(
          isSending: false,
          failedRequestIds: <String>{
            ..._state.failedRequestIds,
            draft.requestId,
          },
          errorMessage: error.toString(),
        ),
      );
      return false;
    }
  }

  Future<void> playMessage({
    required String messageId,
    required String content,
    required String languageCode,
  }) async {
    final String normalized = content.trim();
    if (normalized.isEmpty) return;
    final String cacheKey = '$languageCode\u0000$normalized';
    _setState(_state.copyWith(playingMessageId: messageId, errorMessage: null));
    try {
      final String audioUrl =
          _audioUrlCache[cacheKey] ??
          await _repository.synthesizeSpeech(
            text: normalized,
            languageCode: languageCode,
          );
      _audioUrlCache[cacheKey] = audioUrl;
      await _audioPlayback.playUrl(audioUrl);
    } catch (error) {
      _setState(_state.copyWith(errorMessage: error.toString()));
    } finally {
      if (_state.playingMessageId == messageId) {
        _setState(_state.copyWith(playingMessageId: null));
      }
    }
  }

  Set<String> _withoutFailure(String requestId) {
    return <String>{
      for (final String failedId in _state.failedRequestIds)
        if (failedId != requestId) failedId,
    };
  }

  void _setState(AiChatState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_audioPlayback.stop());
    unawaited(_audioPlayback.dispose());
    super.dispose();
  }
}

class _FailedDraft {
  const _FailedDraft({required this.content, required this.requestId});

  final String content;
  final String requestId;
}

const Object _unset = Object();

List<AiChatMessage> _mergeMessages(
  Iterable<AiChatMessage> first,
  Iterable<AiChatMessage> second,
) {
  final Map<String, AiChatMessage> byId = <String, AiChatMessage>{
    for (final AiChatMessage message in first) message.id: message,
    for (final AiChatMessage message in second) message.id: message,
  };
  final List<AiChatMessage> merged = byId.values.toList(growable: false)
    ..sort(compareAiChatMessagesChronologically);
  return List<AiChatMessage>.unmodifiable(merged);
}

String _newUuidV4() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final String hex = bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
