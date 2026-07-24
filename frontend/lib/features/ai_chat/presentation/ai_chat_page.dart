import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/language/app_language.dart';
import '../../profile/data/subscription_repository.dart';
import '../application/ai_chat_action_catalog.dart';
import '../application/ai_chat_controller.dart';
import '../domain/ai_chat_models.dart';
import 'widgets/ai_chat_bubble.dart';
import 'widgets/ai_chat_composer.dart';

typedef AiChatPremiumLoader = Future<bool> Function();

class AiChatPage extends StatefulWidget {
  const AiChatPage({
    super.key,
    this.conversationId,
    this.controller,
    this.premiumLoader,
    this.onUpgrade,
    this.onOpenHistory,
    this.onOpenAction,
  });

  final String? conversationId;
  final AiChatController? controller;
  final AiChatPremiumLoader? premiumLoader;
  final VoidCallback? onUpgrade;
  final VoidCallback? onOpenHistory;
  final ValueChanged<AiChatSuggestedAction>? onOpenAction;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  late final AiChatController _controller;
  late final bool _ownsController;
  final ScrollController _scrollController = ScrollController();

  bool _checkingPremium = true;
  bool _isPremium = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AiChatController();
    _controller.addListener(_handleControllerChanged);
    _scrollController.addListener(_handleScroll);
    final String? conversationId = widget.conversationId?.trim();
    if (conversationId != null && conversationId.isNotEmpty) {
      unawaited(_controller.loadConversation(conversationId));
    }
    unawaited(_loadPremium());
  }

  Future<void> _loadPremium() async {
    bool isPremium = false;
    try {
      isPremium = await (widget.premiumLoader ?? _defaultPremiumLoader)();
    } catch (_) {
      isPremium = false;
    }
    if (!mounted) return;
    setState(() {
      _isPremium = isPremium;
      _checkingPremium = false;
    });
  }

  Future<bool> _defaultPremiumLoader() async {
    return (await SubscriptionRepository().loadCurrentSubscription()) != null;
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
    final int messageCount = _controller.state.messages.length;
    if (messageCount > _lastMessageCount) {
      _lastMessageCount = messageCount;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 120) {
      unawaited(_controller.loadOlderMessages());
    }
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    unawaited(
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      ),
    );
  }

  void _openHistory() {
    final VoidCallback? callback = widget.onOpenHistory;
    if (callback != null) {
      callback();
      return;
    }
    context.push(AppRoutes.aiChatHistory);
  }

  void _openUpgrade() {
    final VoidCallback? callback = widget.onUpgrade;
    if (callback != null) {
      callback();
      return;
    }
    context.push(AppRoutes.upgradeAccount);
  }

  void _openAction(AiChatSuggestedAction action) {
    final AiChatActionDestination? destination =
        AiChatActionCatalog.destinationFor(action.key);
    if (destination == null) return;
    final ValueChanged<AiChatSuggestedAction>? callback = widget.onOpenAction;
    if (callback != null) {
      callback(action);
      return;
    }
    context.push(destination.route);
  }

  String _speechLanguageCode() {
    return Localizations.localeOf(context).languageCode == 'vi'
        ? 'vi-VN'
        : 'en-US';
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AiChatState state = _controller.state;
    final bool hasExistingConversation =
        widget.conversationId?.trim().isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.ui('AI Travel Assistant')),
        actions: <Widget>[
          IconButton(
            key: const Key('ai-chat-history'),
            tooltip: context.l10n.ui('Chat history'),
            onPressed: _openHistory,
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: _checkingPremium
          ? const Center(child: CircularProgressIndicator())
          : !_isPremium && !hasExistingConversation
          ? _PremiumGate(onUpgrade: _openUpgrade)
          : Column(
              children: <Widget>[
                if (!_isPremium) _ExpiredPremiumNotice(onUpgrade: _openUpgrade),
                Expanded(child: _buildMessages(state)),
                if (_isPremium)
                  AiChatComposer(
                    key: const Key('ai-chat-composer'),
                    isSending: state.isSending,
                    onSend: _controller.send,
                  ),
              ],
            ),
    );
  }

  Widget _buildMessages(AiChatState state) {
    if (state.isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.messages.isEmpty) {
      if (state.errorMessage != null) {
        return _ChatStatus(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load this conversation',
          subtitle: state.errorMessage!,
          actionLabel: widget.conversationId == null ? null : 'Retry',
          onAction: widget.conversationId == null
              ? null
              : () => _controller.loadConversation(widget.conversationId!),
        );
      }
      return const _ChatStatus(
        icon: Icons.travel_explore_rounded,
        title: 'How can I help with your Vietnam trip?',
        subtitle:
            'Ask for travel ideas, useful local information, or help finding an app feature.',
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: state.messages.length + (state.isLoadingOlder ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        if (state.isLoadingOlder && index == 0) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final int messageIndex = state.isLoadingOlder ? index - 1 : index;
        final AiChatMessage message = state.messages[messageIndex];
        return AiChatBubble(
          message: message,
          isFailed: state.isMessageFailed(message),
          isPlaying: state.playingMessageId == message.id,
          canUsePremium: _isPremium,
          onRetry: _controller.retryLastSend,
          onSpeak: () => _controller.playMessage(
            messageId: message.id,
            content: message.content,
            languageCode: _speechLanguageCode(),
          ),
          onAction: _openAction,
        );
      },
    );
  }
}

class _PremiumGate extends StatelessWidget {
  const _PremiumGate({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircleAvatar(
                radius: 34,
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 34,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.ui('Premium travel assistant'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.ui(
                  'Chat with AI for personalized Vietnam travel help and quick access to relevant app features.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('ai-chat-upgrade'),
                onPressed: onUpgrade,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: Text(context.l10n.ui('View Premium plans')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpiredPremiumNotice extends StatelessWidget {
  const _ExpiredPremiumNotice({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            const Icon(Icons.lock_outline_rounded),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.ui('Renew Premium to continue this conversation.'),
              ),
            ),
            TextButton(
              onPressed: onUpgrade,
              child: Text(context.l10n.ui('Renew')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatStatus extends StatelessWidget {
  const _ChatStatus({
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 44, color: colors.primary),
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
                OutlinedButton(
                  onPressed: onAction,
                  child: Text(context.l10n.ui(actionLabel!)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
