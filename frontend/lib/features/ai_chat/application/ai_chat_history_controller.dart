import 'package:flutter/foundation.dart';

import '../data/ai_chat_repository.dart';
import '../domain/ai_chat_models.dart';

class AiChatHistoryState {
  const AiChatHistoryState({
    this.conversations = const <AiChatConversation>[],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.nextCursor,
    this.errorMessage,
  });

  final List<AiChatConversation> conversations;
  final bool isLoading;
  final bool isLoadingMore;
  final String? nextCursor;
  final String? errorMessage;

  bool get hasMore => nextCursor != null;

  AiChatHistoryState copyWith({
    List<AiChatConversation>? conversations,
    bool? isLoading,
    bool? isLoadingMore,
    Object? nextCursor = _unset,
    Object? errorMessage = _unset,
  }) {
    return AiChatHistoryState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      nextCursor: identical(nextCursor, _unset)
          ? this.nextCursor
          : nextCursor as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AiChatHistoryController extends ChangeNotifier {
  AiChatHistoryController({AiChatRepositoryContract? repository})
    : _repository = repository ?? AiChatRepository();

  final AiChatRepositoryContract _repository;
  AiChatHistoryState _state = const AiChatHistoryState();
  bool _disposed = false;

  AiChatHistoryState get state => _state;

  Future<void> load() async {
    if (_state.isLoading) return;
    _setState(const AiChatHistoryState(isLoading: true));
    try {
      final AiChatConversationPage page = await _repository.listConversations();
      _setState(
        AiChatHistoryState(
          conversations: page.items,
          nextCursor: page.nextCursor,
        ),
      );
    } catch (error) {
      _setState(AiChatHistoryState(errorMessage: error.toString()));
    }
  }

  Future<void> loadMore() async {
    final String? cursor = _state.nextCursor;
    if (cursor == null || _state.isLoading || _state.isLoadingMore) return;
    _setState(_state.copyWith(isLoadingMore: true, errorMessage: null));
    try {
      final AiChatConversationPage page = await _repository.listConversations(
        cursor: cursor,
      );
      _setState(
        _state.copyWith(
          conversations: _merge(_state.conversations, page.items),
          isLoadingMore: false,
          nextCursor: page.nextCursor,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(isLoadingMore: false, errorMessage: error.toString()),
      );
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    final List<AiChatConversation> previous = _state.conversations;
    _setState(
      _state.copyWith(
        conversations: previous
            .where((item) => item.id != conversationId)
            .toList(growable: false),
        errorMessage: null,
      ),
    );
    try {
      await _repository.deleteConversation(conversationId);
    } catch (error) {
      _setState(
        _state.copyWith(
          conversations: previous,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  List<AiChatConversation> _merge(
    List<AiChatConversation> existing,
    List<AiChatConversation> incoming,
  ) {
    final Map<String, AiChatConversation> byId = <String, AiChatConversation>{
      for (final AiChatConversation conversation in existing)
        conversation.id: conversation,
      for (final AiChatConversation conversation in incoming)
        conversation.id: conversation,
    };
    final List<AiChatConversation> merged = byId.values.toList(growable: false)
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return List<AiChatConversation>.unmodifiable(merged);
  }

  void _setState(AiChatHistoryState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

const Object _unset = Object();
