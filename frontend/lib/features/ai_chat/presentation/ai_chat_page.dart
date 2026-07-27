import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/language/app_language.dart';
import '../../profile/application/premium_entitlement_controller.dart';
import '../application/ai_chat_action_catalog.dart';
import '../application/ai_chat_controller.dart';
import '../domain/ai_chat_models.dart';
import 'ai_chat_list_change.dart';
import 'widgets/ai_chat_bubble.dart';
import 'widgets/ai_chat_background.dart';
import 'widgets/ai_chat_composer.dart';
import 'widgets/lac_bird_avatar.dart';
import 'widgets/liquid_glass_panel.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({
    super.key,
    this.conversationId,
    this.controller,
    this.entitlementController,
    this.onUpgrade,
    this.onOpenHistory,
    this.onOpenAction,
  });

  final String? conversationId;
  final AiChatController? controller;
  final PremiumEntitlementController? entitlementController;
  final VoidCallback? onUpgrade;
  final VoidCallback? onOpenHistory;
  final ValueChanged<AiChatSuggestedAction>? onOpenAction;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  late final AiChatController _controller;
  late final bool _ownsController;
  late final PremiumEntitlementController _entitlementController;
  final ScrollController _scrollController = ScrollController();

  List<String> _lastMessageIds = const <String>[];

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AiChatController();
    _entitlementController =
        widget.entitlementController ?? PremiumEntitlementController.instance;
    _controller.addListener(_handleControllerChanged);
    _entitlementController.addListener(_handleEntitlementChanged);
    _scrollController.addListener(_handleScroll);
    final String? conversationId = widget.conversationId?.trim();
    if (conversationId != null && conversationId.isNotEmpty) {
      unawaited(_controller.loadConversation(conversationId));
    }
  }

  void _handleEntitlementChanged() {
    if (mounted) setState(() {});
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final List<String> currentIds = _controller.state.messages
        .map((AiChatMessage message) => message.id)
        .toList(growable: false);
    final AiChatListChange change = detectAiChatListChange(
      previousIds: _lastMessageIds,
      currentIds: currentIds,
    );
    _lastMessageIds = currentIds;
    if (change == AiChatListChange.none) return;

    final bool shouldAutoScroll =
        !_scrollController.hasClients ||
        shouldAutoScrollAiChatAppend(
          currentOffset: _scrollController.offset,
          maxScrollExtent: _scrollController.position.maxScrollExtent,
        );
    final double oldMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0;
    final double oldOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (change == AiChatListChange.prepended) {
        final double extentDelta =
            _scrollController.position.maxScrollExtent - oldMaxExtent;
        _scrollController.jumpTo(
          (oldOffset + extentDelta).clamp(
            0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      } else if (shouldAutoScroll) {
        _scrollToLatest();
      }
    });
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
    _entitlementController.removeListener(_handleEntitlementChanged);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasExistingConversation =
        widget.conversationId?.trim().isNotEmpty == true;
    final PremiumEntitlementStatus status = _entitlementController.state.status;
    final bool canUsePremium = _entitlementController.canUsePremium;

    final Widget content = status == PremiumEntitlementStatus.loading
        ? const Center(
            key: Key('ai-chat-premium-loading'),
            child: CircularProgressIndicator(),
          )
        : status == PremiumEntitlementStatus.inactive &&
              !hasExistingConversation
        ? _PremiumGate(onUpgrade: _openUpgrade)
        : !canUsePremium &&
              status != PremiumEntitlementStatus.inactive &&
              !hasExistingConversation
        ? _PremiumVerificationError(onRetry: _entitlementController.retry)
        : ListenableBuilder(
            listenable: _controller,
            builder: (BuildContext context, Widget? child) {
              final AiChatState currentState = _controller.state;
              return Column(
                children: <Widget>[
                  if (!canUsePremium &&
                      status == PremiumEntitlementStatus.inactive)
                    _ExpiredPremiumNotice(onUpgrade: _openUpgrade),
                  if (!canUsePremium &&
                      status != PremiumEntitlementStatus.inactive)
                    _PremiumVerificationNotice(
                      onRetry: _entitlementController.retry,
                    ),
                  Expanded(child: _buildMessages(currentState)),
                  if (canUsePremium)
                    AiChatComposer(
                      key: const Key('ai-chat-composer'),
                      isSending: currentState.isSending,
                      onSend: _controller.send,
                    ),
                ],
              );
            },
          );

    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020B12)
          : const Color(0xFFF4FCFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: LiquidGlassPanel(
          key: const Key('ai-chat-glass-app-bar'),
          borderRadius: 0,
          blur: 22,
          tint: isDark
              ? const Color(0xFF102C3B).withValues(alpha: 0.92)
              : const Color(0xFFDDF4FF).withValues(alpha: 0.96),
          borderColor: isDark
              ? Colors.white.withValues(alpha: 0.16)
              : colors.primary.withValues(alpha: 0.20),
          child: const SizedBox.expand(),
        ),
        titleSpacing: 4,
        title: Row(
          children: <Widget>[
            LiquidGlassPanel(
              borderRadius: 16,
              blur: 10,
              padding: const EdgeInsets.all(4),
              child: LacBirdAvatar(size: 28, color: colors.primary),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                context.l10n.ui('AI Travel Assistant'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: LiquidGlassPanel(
              borderRadius: 22,
              blur: 12,
              child: IconButton(
                key: const Key('ai-chat-history'),
                tooltip: context.l10n.ui('Chat history'),
                onPressed: _openHistory,
                icon: const Icon(Icons.history_rounded),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: AiChatBackground()),
          Positioned.fill(child: content),
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
      return _ChatStatus(
        icon: Icons.travel_explore_rounded,
        title: context.l10n.ui('Where shall we explore in Vietnam?'),
        subtitle: context.l10n.ui(
          'Ask for travel ideas, useful local information, or help finding an app feature.',
        ),
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
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (BuildContext context, double value, Widget? child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - value)),
                child: child,
              ),
            );
          },
          child: AiChatBubble(
            message: message,
            isFailed: state.isMessageFailed(message),
            isPlaying: state.playingMessageId == message.id,
            canUsePremium: _entitlementController.canUsePremium,
            onRetry: _controller.retryLastSend,
            onSpeak: () => _controller.playMessage(
              messageId: message.id,
              content: message.content,
              languageCode: _speechLanguageCode(),
            ),
            onAction: _openAction,
          ),
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

class _PremiumVerificationError extends StatelessWidget {
  const _PremiumVerificationError({required this.onRetry});

  final Future<void> Function() onRetry;

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
              Icon(Icons.cloud_off_rounded, size: 48, color: colors.primary),
              const SizedBox(height: 16),
              Text(
                context.l10n.ui('Unable to verify Premium right now.'),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.ui(
                  'Check your connection and retry. Your account has not been marked as Free.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('ai-chat-premium-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.ui('Retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumVerificationNotice extends StatelessWidget {
  const _PremiumVerificationNotice({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            const Icon(Icons.cloud_off_rounded),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.ui(
                  'Premium verification is temporarily unavailable.',
                ),
              ),
            ),
            TextButton(
              key: const Key('ai-chat-premium-retry'),
              onPressed: onRetry,
              child: Text(context.l10n.ui('Retry')),
            ),
          ],
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
