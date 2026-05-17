import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hellovietnam/features/translate/data/openai_translation_service.dart';
import 'package:go_router/go_router.dart';

class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage>
    with SingleTickerProviderStateMixin {
  static const List<_LanguageOption> _allLanguages = <_LanguageOption>[
    _LanguageOption(code: 'auto', shortLabel: 'Auto', name: 'Auto detect'),
    _LanguageOption(
      code: 'vi',
      shortLabel: 'Viet',
      name: 'Vietnamese',
      flagCode: 'vn',
    ),
    _LanguageOption(
      code: 'en',
      shortLabel: 'Eng',
      name: 'English',
      flagCode: 'gb',
    ),
    _LanguageOption(
      code: 'zh',
      shortLabel: 'Chi',
      name: 'Chinese',
      flagCode: 'cn',
    ),
    _LanguageOption(
      code: 'ja',
      shortLabel: 'Jpn',
      name: 'Japanese',
      flagCode: 'jp',
    ),
    _LanguageOption(
      code: 'ko',
      shortLabel: 'Kor',
      name: 'Korean',
      flagCode: 'kr',
    ),
    _LanguageOption(
      code: 'fr',
      shortLabel: 'Fre',
      name: 'French',
      flagCode: 'fr',
    ),
    _LanguageOption(
      code: 'de',
      shortLabel: 'Ger',
      name: 'German',
      flagCode: 'de',
    ),
    _LanguageOption(
      code: 'es',
      shortLabel: 'Spa',
      name: 'Spanish',
      flagCode: 'es',
    ),
    _LanguageOption(
      code: 'it',
      shortLabel: 'Ita',
      name: 'Italian',
      flagCode: 'it',
    ),
    _LanguageOption(
      code: 'pt',
      shortLabel: 'Por',
      name: 'Portuguese',
      flagCode: 'pt',
    ),
  ];

  static const List<String> _quickExamples = <String>[
    'Hello, how are you?',
    'Thank you very much',
    'こんにちは',
    '안녕하세요',
    '你好，最近怎么样？',
  ];

  final TextEditingController _inputController = TextEditingController();
  final OpenAITranslationService _translationService = OpenAITranslationService();
  _LanguageOption _source = _allLanguages[2];
  _LanguageOption _target = _allLanguages[1];
  bool _isListening = false;
  bool _isTranslating = false;
  String _translatedText = '';
  String? _translationError;
  Timer? _translateDebounce;
  int _translationRequestId = 0;
  late final AnimationController _swapButtonController;
  late final Animation<double> _swapIconTurn;

  @override
  void initState() {
    super.initState();
    _swapButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _swapIconTurn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _swapButtonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _translateDebounce?.cancel();
    _swapButtonController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _scheduleTranslate({String? text, bool immediate = false}) {
    _translateDebounce?.cancel();

    final String value = (text ?? _inputController.text).trim();
    if (value.isEmpty) {
      setState(() {
        _isTranslating = false;
        _translatedText = '';
        _translationError = null;
      });
      return;
    }

    if (_source.code != 'auto' && _source.code == _target.code) {
      setState(() {
        _isTranslating = false;
        _translatedText = value;
        _translationError = null;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
      _translationError = null;
    });

    if (immediate) {
      unawaited(_translate(value));
      return;
    }

    _translateDebounce = Timer(const Duration(milliseconds: 550), () {
      unawaited(_translate(value));
    });
  }

  Future<void> _translate(String text) async {
    final int requestId = ++_translationRequestId;

    try {
      final TranslationResult result = await _translationService.translate(
        text: text,
        sourceLanguageCode: _source.code,
        targetLanguageCode: _target.code,
        targetLanguageName: _target.name,
      );

      if (!mounted || requestId != _translationRequestId) {
        return;
      }

      setState(() {
        _translatedText = result.translatedText;
        _translationError = null;
        _isTranslating = false;
      });
    } on TranslationException catch (error) {
      if (!mounted || requestId != _translationRequestId) {
        return;
      }

      setState(() {
        _translationError = error.message;
        _isTranslating = false;
      });
    } catch (_) {
      if (!mounted || requestId != _translationRequestId) {
        return;
      }

      setState(() {
        _translationError = 'Khong the dich luc nay. Vui long thu lai.';
        _isTranslating = false;
      });
    }
  }

  Future<void> _openLanguageSheet({required bool selectingSource}) async {
    final _LanguageOption? selected = await showModalBottomSheet<_LanguageOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _LanguagePickerSheet(
          languages: _allLanguages,
          selectedCode: selectingSource ? _source.code : _target.code,
          allowAutoDetect: selectingSource,
        );
      },
    );

    if (selected == null) return;

    setState(() {
      if (selectingSource) {
        _source = selected;
      } else {
        _target = selected;
      }
    });

    _scheduleTranslate(immediate: true);
  }

  void _swapLanguages() {
    _swapButtonController.forward(from: 0);
    if (_source.code == 'auto') {
      setState(() {
        _source = _allLanguages[2];
        _target = _allLanguages[1];
      });
      _scheduleTranslate(immediate: true);
      return;
    }

    setState(() {
      final _LanguageOption temp = _source;
      _source = _target;
      _target = temp;
    });
    _scheduleTranslate(immediate: true);
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
    });
  }

  void _handleQuickExample(String value) {
    _inputController.text = value;
    setState(() {
      _isListening = false;
    });
    _scheduleTranslate(text: value, immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          size: 35,
                          color: Color(0xFF35A8E8),
                        ),
                        splashRadius: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Translate',
                        style: TextStyle(
                          fontSize: 33,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2735),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _LanguageChip(
                            language: _source,
                            isSource: true,
                            onTap: () => _openLanguageSheet(selectingSource: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _swapLanguages,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2FAFEF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: RotationTransition(
                              turns: _swapIconTurn,
                              child: const Icon(
                                Icons.swap_horiz_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _LanguageChip(
                            language: _target,
                            isSource: false,
                            onTap: () => _openLanguageSheet(selectingSource: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  14,
                  0,
                  14,
                  MediaQuery.of(context).padding.bottom + 20,
                ),
                child: Column(
                  children: <Widget>[
                    _InputCard(
                      source: _source,
                      controller: _inputController,
                      isListening: _isListening,
                      onToggleListening: _toggleListening,
                      onChanged: (String value) {
                        _scheduleTranslate(text: value);
                      },
                      onClear: () {
                        _inputController.clear();
                        setState(() {
                          _translatedText = '';
                          _isListening = false;
                          _isTranslating = false;
                          _translationError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _OutputCard(
                      target: _target,
                      translatedText: _translatedText,
                      isLoading: _isTranslating,
                      errorText: _translationError,
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'QUICK EXAMPLES',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7B8596),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List<Widget>.generate(_quickExamples.length, (int index) {
                      final String text = _quickExamples[index];
                      final _LanguageOption languageForItem = index < 2
                          ? _allLanguages[2]
                          : index == 2
                              ? _allLanguages[4]
                              : index == 3
                                  ? _allLanguages[5]
                                  : _allLanguages[3];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _QuickExampleTile(
                          text: text,
                          language: languageForItem,
                          onTap: () => _handleQuickExample(text),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.language,
    required this.isSource,
    required this.onTap,
  });

  final _LanguageOption language;
  final bool isSource;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSource ? const Color(0xFFEAF5FF) : const Color(0xFFF0FBF2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSource
                ? const Color(0xFFAEDBFB)
                : const Color(0xFFC3ECCA),
          ),
        ),
        child: Row(
          children: <Widget>[
            _RoundFlag(flagCode: language.flagCode),
            const SizedBox(width: 8),
            Text(
              language.shortLabel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSource
                    ? const Color(0xFF334B69)
                    : const Color(0xFF2E5A36),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF8A97A8),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.source,
    required this.controller,
    required this.isListening,
    required this.onToggleListening,
    required this.onChanged,
    required this.onClear,
  });

  final _LanguageOption source;
  final TextEditingController controller;
  final bool isListening;
  final VoidCallback onToggleListening;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _RoundFlag(flagCode: source.flagCode, radius: 8),
              const SizedBox(width: 6),
              Text(
                source.name,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8A96A8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onToggleListening,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isListening
                        ? const Color(0xFFFFEBED)
                        : const Color(0xFFF2F4F7),
                  ),
                  child: Icon(
                    Icons.mic_none_rounded,
                    size: 16,
                    color: isListening
                        ? const Color(0xFFFF6363)
                        : const Color(0xFF9AA5B5),
                  ),
                ),
              ),
              if (controller.text.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF2F4F7),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF9AA5B5),
                    ),
                  ),
                ),
              ],
            ],
          ),
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter text to translate...',
              hintStyle: TextStyle(fontSize: 16, color: Color(0xFFA6B0BF)),
              border: InputBorder.none,
            ),
            style: const TextStyle(fontSize: 17, color: Color(0xFF1D2A3B)),
          ),
                    if (isListening)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 6),
              child: Row(
                children: <Widget>[
                  _ListeningWaveIndicator(),
                  SizedBox(width: 8),
                  Text(
                    'Listening...',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFFF7B7B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${controller.text.length}/1000',
              style: const TextStyle(fontSize: 12, color: Color(0xFFC2C9D3)),
            ),
          ),
        ],
      ),
    );
  }
}


class _ListeningWaveIndicator extends StatefulWidget {
  const _ListeningWaveIndicator();

  @override
  State<_ListeningWaveIndicator> createState() => _ListeningWaveIndicatorState();
}

class _ListeningWaveIndicatorState extends State<_ListeningWaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Row(
            children: List<Widget>.generate(5, (int index) {
              final double phase = (_controller.value + index * 0.14) * math.pi * 2;
              final double barHeight = 4 + (math.sin(phase).abs() * 8);
              return Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Container(
                  width: 3,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7B7B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  const _OutputCard({
    required this.target,
    required this.translatedText,
    required this.isLoading,
    this.errorText,
  });

  final _LanguageOption target;
  final String translatedText;
  final bool isLoading;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.trim().isNotEmpty;
    final bool hasTranslation = translatedText.trim().isNotEmpty;
    final String bodyText = hasError
        ? errorText!
        : isLoading
            ? 'Translating...'
            : hasTranslation
                ? translatedText
                : 'Translation appears here';
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 154),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF7ED0F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _RoundFlag(flagCode: target.flagCode, radius: 8),
              const SizedBox(width: 6),
              Text(
                target.name,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE1F6FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isLoading) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 1),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ] else if (hasTranslation && !hasError) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'DONE',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (hasTranslation) ...<Widget>[
                const Icon(Icons.volume_up_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
              ],
            ],
            ),
          const SizedBox(height: 12),
          Text(
            bodyText,
            style: TextStyle(
              fontSize: 22,
              color: hasError
                  ? const Color(0xFFFDF2F2)
                  : hasTranslation || isLoading
                      ? Colors.white
                      : const Color(0xA0EAF7FF),
              fontWeight:
                  hasTranslation || isLoading || hasError
                      ? FontWeight.w600
                      : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickExampleTile extends StatelessWidget {
  const _QuickExampleTile({
    required this.text,
    required this.language,
    required this.onTap,
  });

  final String text;
  final _LanguageOption language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            _RoundFlag(flagCode: language.flagCode, radius: 8),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF3A4455),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFD0D5DE)),
          ],
        ),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({
    required this.languages,
    required this.selectedCode,
    required this.allowAutoDetect,
  });

  final List<_LanguageOption> languages;
  final String selectedCode;
  final bool allowAutoDetect;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final List<_LanguageOption> options = widget.languages.where((_LanguageOption item) {
      if (!widget.allowAutoDetect && item.code == 'auto') return false;
      return item.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.74,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDFE4EB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Select Language',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF242D3D),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFFA4ACB9)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                onChanged: (String value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search language...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Color(0xFFB0B8C4),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (BuildContext context, int index) {
                final _LanguageOption item = options[index];
                final bool selected = item.code == widget.selectedCode;
                return InkWell(
                  onTap: () => context.pop(item),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFEEF4FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: <Widget>[
                        _RoundFlag(flagCode: item.flagCode, radius: 9),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                              color: selected
                                  ? const Color(0xFF2E74DA)
                                  : const Color(0xFF4A5567),
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_rounded, color: Color(0xFF4B9AF4)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundFlag extends StatelessWidget {
  const _RoundFlag({required this.flagCode, this.radius = 9});

  final String? flagCode;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD6DEE9)),
      ),
      alignment: Alignment.center,
      child: flagCode == null
          ? Icon(
              Icons.public_rounded,
              size: radius + 2,
              color: const Color(0xFF6AA9CC),
            )
          : ClipOval(
              child: Image.network(
                'https://flagcdn.com/w40/${flagCode!.toLowerCase()}.png',
                width: radius * 2 - 2,
                height: radius * 2 - 2,
                fit: BoxFit.cover,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) => Container(
                  color: const Color(0xFFEAF0F8),
                  alignment: Alignment.center,
                  child: Text(
                    flagCode!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6F7D90),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption({
    required this.code,
    required this.shortLabel,
    required this.name,
    this.flagCode,
  });

  final String code;
  final String shortLabel;
  final String name;
  final String? flagCode;
}
