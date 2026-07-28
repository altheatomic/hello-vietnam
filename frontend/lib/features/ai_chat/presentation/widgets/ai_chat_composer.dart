import 'package:flutter/material.dart';

import '../../../../core/language/app_language.dart';
import 'liquid_glass_panel.dart';

class AiChatComposer extends StatefulWidget {
  const AiChatComposer({
    super.key,
    required this.isSending,
    required this.onSend,
  });

  final bool isSending;
  final Future<bool> Function(String content) onSend;

  @override
  State<AiChatComposer> createState() => _AiChatComposerState();
}

class _AiChatComposerState extends State<AiChatComposer> {
  static const int _maxLength = 2000;

  final TextEditingController _controller = TextEditingController();
  bool _hasContent = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    final bool hasContent = _controller.text.trim().isNotEmpty;
    if (hasContent == _hasContent) return;
    setState(() => _hasContent = hasContent);
  }

  Future<void> _submit() async {
    final String content = _controller.text.trim();
    if (content.isEmpty || widget.isSending) return;
    FocusScope.of(context).unfocus();
    final bool sent = await widget.onSend(content);
    if (!mounted) return;
    if (sent) _controller.clear();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canSend = _hasContent && !widget.isSending;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: LiquidGlassPanel(
        key: const Key('ai-chat-glass-composer'),
        borderRadius: 28,
        blur: 22,
        tint: colors.surface.withValues(alpha: isDark ? 0.70 : 0.62),
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const Key('ai-chat-input'),
                controller: _controller,
                enabled: !widget.isSending,
                minLines: 1,
                maxLines: 5,
                maxLength: _maxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: context.l10n.ui(
                    'Ask about your trip in Vietnam...',
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: colors.surface.withValues(
                    alpha: isDark ? 0.42 : 0.46,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.08 : 0.54,
                      ),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: colors.primary.withValues(alpha: 0.72),
                      width: 1.2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              key: const Key('ai-chat-send-surface'),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: canSend
                    ? null
                    : isDark
                    ? const Color(0xFF17384A).withValues(alpha: 0.88)
                    : const Color(0xFFDDF4FF),
                gradient: canSend
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFF69C9F1), Color(0xFF36BFD5)],
                      )
                    : null,
                border: Border.all(
                  color: canSend
                      ? Colors.white.withValues(alpha: 0.46)
                      : colors.primary.withValues(alpha: isDark ? 0.18 : 0.30),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colors.primary.withValues(
                      alpha: canSend ? 0.28 : 0.12,
                    ),
                    blurRadius: canSend ? 14 : 8,
                    offset: Offset(0, canSend ? 5 : 3),
                  ),
                ],
              ),
              child: IconButton(
                key: const Key('ai-chat-send'),
                tooltip: context.l10n.ui('Send'),
                color: Colors.white,
                disabledColor: isDark
                    ? colors.onSurface.withValues(alpha: 0.56)
                    : colors.primary,
                onPressed: canSend ? _submit : null,
                icon: widget.isSending
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
