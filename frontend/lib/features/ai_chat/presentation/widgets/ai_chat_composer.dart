import 'package:flutter/material.dart';

import '../../../../core/language/app_language.dart';

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
    return Material(
      color: colors.surface,
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
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
                    fillColor: colors.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const Key('ai-chat-send'),
                tooltip: context.l10n.ui('Send'),
                onPressed: _hasContent && !widget.isSending ? _submit : null,
                icon: widget.isSending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
