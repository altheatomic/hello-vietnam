import 'package:flutter/material.dart';

import '../../../../core/language/app_language.dart';
import '../../application/ai_chat_action_catalog.dart';
import '../../domain/ai_chat_models.dart';
import 'lac_bird_avatar.dart';
import 'liquid_glass_panel.dart';

class AiChatBubble extends StatelessWidget {
  const AiChatBubble({
    super.key,
    required this.message,
    required this.isFailed,
    required this.isPlaying,
    required this.canUsePremium,
    required this.onRetry,
    required this.onSpeak,
    required this.onAction,
  });

  final AiChatMessage message;
  final bool isFailed;
  final bool isPlaying;
  final bool canUsePremium;
  final VoidCallback onRetry;
  final VoidCallback onSpeak;
  final ValueChanged<AiChatSuggestedAction> onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final AiChatActionDestination? destination =
        AiChatActionCatalog.destinationFor(message.action?.key);
    final Color foreground = message.isUser
        ? colors.onPrimaryContainer
        : colors.onSurface;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: EdgeInsets.only(
            left: message.isUser ? 44 : 0,
            right: message.isUser ? 0 : 44,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: <Widget>[
              if (!message.isUser) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: LiquidGlassPanel(
                    borderRadius: 18,
                    padding: const EdgeInsets.all(5),
                    blur: 12,
                    child: LacBirdAvatar(size: 26, color: colors.primary),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: LiquidGlassPanel(
                  key: const Key('ai-chat-glass-bubble'),
                  borderRadius: 22,
                  blur: 16,
                  tint: message.isUser
                      ? colors.primaryContainer.withValues(
                          alpha: isDark ? 0.72 : 0.78,
                        )
                      : colors.surface.withValues(alpha: isDark ? 0.68 : 0.58),
                  borderColor: isFailed
                      ? colors.error
                      : Colors.white.withValues(alpha: isDark ? 0.14 : 0.72),
                  padding: const EdgeInsets.fromLTRB(15, 12, 13, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        message.content,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: foreground,
                          height: 1.42,
                        ),
                      ),
                      if (!message.isUser && canUsePremium) ...<Widget>[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            key: Key('ai-chat-speak-${message.id}'),
                            tooltip: context.l10n.ui('Listen'),
                            visualDensity: VisualDensity.compact,
                            onPressed: isPlaying ? null : onSpeak,
                            icon: isPlaying
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.volume_up_outlined),
                          ),
                        ),
                      ],
                      if (destination != null &&
                          message.action != null) ...<Widget>[
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          key: Key('ai-chat-action-${destination.key}'),
                          onPressed: () => onAction(message.action!),
                          icon: Icon(destination.icon),
                          label: Text(context.l10n.ui(destination.label)),
                        ),
                      ],
                      if (isFailed) ...<Widget>[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: onRetry,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.error,
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(context.l10n.ui('Try again')),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
