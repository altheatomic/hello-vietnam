import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/language/app_language.dart';
import '../application/ai_chat_history_controller.dart';
import '../domain/ai_chat_models.dart';

class AiChatHistoryPage extends StatefulWidget {
  const AiChatHistoryPage({
    super.key,
    this.controller,
    this.onOpenConversation,
  });

  final AiChatHistoryController? controller;
  final ValueChanged<String>? onOpenConversation;

  @override
  State<AiChatHistoryPage> createState() => _AiChatHistoryPageState();
}

class _AiChatHistoryPageState extends State<AiChatHistoryPage> {
  late final AiChatHistoryController _controller;
  late final bool _ownsController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AiChatHistoryController();
    _controller.addListener(_handleChanged);
    _scrollController.addListener(_handleScroll);
    unawaited(_controller.load());
  }

  void _handleChanged() {
    if (mounted) setState(() {});
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final ScrollPosition position = _scrollController.position;
    if (position.extentAfter < 240) {
      unawaited(_controller.loadMore());
    }
  }

  void _openConversation(String conversationId) {
    final ValueChanged<String>? callback = widget.onOpenConversation;
    if (callback != null) {
      callback(conversationId);
      return;
    }
    context.push(
      Uri(
        path: AppRoutes.aiChat,
        queryParameters: <String, String>{'conversationId': conversationId},
      ).toString(),
    );
  }

  Future<void> _requestDelete(AiChatConversation conversation) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.ui('Delete conversation?')),
          content: Text(
            context.l10n.ui(
              'This conversation and all its messages will be removed.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.ui('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(context.l10n.ui('Delete')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _controller.deleteConversation(conversation.id);
    if (!mounted || _controller.state.errorMessage == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.ui('Could not delete this conversation.')),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AiChatHistoryState state = _controller.state;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.ui('AI chat history')),
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.ui('Refresh'),
            onPressed: state.isLoading ? null : _controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(AiChatHistoryState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.conversations.isEmpty && state.errorMessage != null) {
      return _HistoryStatus(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load chat history',
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _controller.load,
      );
    }
    if (state.conversations.isEmpty) {
      return const _HistoryStatus(
        icon: Icons.forum_outlined,
        title: 'No conversations yet',
        subtitle: 'Your AI travel conversations will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: state.conversations.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          if (index == state.conversations.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return _conversationTile(state.conversations[index]);
        },
      ),
    );
  }

  Widget _conversationTile(AiChatConversation conversation) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('ai-chat-history-open-${conversation.id}'),
        onTap: () => _openConversation(conversation.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: const Icon(Icons.auto_awesome_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      conversation.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatUpdatedAt(conversation.updatedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('ai-chat-history-delete-${conversation.id}'),
                tooltip: context.l10n.ui('Delete'),
                onPressed: () => _requestDelete(conversation),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatUpdatedAt(DateTime value) {
    final DateTime local = value.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $hour:$minute';
  }
}

class _HistoryStatus extends StatelessWidget {
  const _HistoryStatus({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: colors.primary),
            const SizedBox(height: 14),
            Text(
              context.l10n.ui(title),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.ui(subtitle),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                child: Text(context.l10n.ui(actionLabel!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
