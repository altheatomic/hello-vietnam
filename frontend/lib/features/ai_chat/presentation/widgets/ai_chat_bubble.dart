import 'package:flutter/material.dart';

import '../../../../core/language/app_language.dart';
import '../../application/ai_chat_action_catalog.dart';
import '../../domain/ai_chat_models.dart';

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
    final AiChatActionDestination? destination =
        AiChatActionCatalog.destinationFor(message.action?.key);
    final Color bubbleColor = message.isUser
        ? colors.primary
        : colors.surfaceContainerHighest;
    final Color foreground = message.isUser
        ? colors.onPrimary
        : colors.onSurface;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: EdgeInsets.only(
            left: message.isUser ? 44 : 0,
            right: message.isUser ? 0 : 44,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(8),
            border: isFailed
                ? Border.all(color: colors.error, width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message.content,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: foreground),
              ),
              if (!message.isUser && canUsePremium) ...<Widget>[
                const SizedBox(height: 6),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.volume_up_outlined),
                  ),
                ),
              ],
              if (destination != null && message.action != null) ...<Widget>[
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
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.l10n.ui('Try again')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
