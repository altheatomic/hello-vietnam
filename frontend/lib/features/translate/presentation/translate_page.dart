import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/profile/application/premium_entitlement_controller.dart';
import 'package:hellovietnam/features/translate/data/openai_translation_service.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/features/translate/data/offline_translation_service.dart';
import 'package:hellovietnam/features/translate/data/tts_service.dart';

enum TranslateMode { basic, premium }

class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key, this.entitlementController});

  final PremiumEntitlementController? entitlementController;

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
  final OpenAITranslationService _translationService =
      OpenAITranslationService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  _LanguageOption _source = _allLanguages[2];
  _LanguageOption _target = _allLanguages[1];
  bool _isTranslating = false;
  String _translatedText = '';
  String? _translationError;
  int _translationRequestId = 0;
  TranslateMode _mode = TranslateMode.basic;
  bool _isCheckingPremium = false;
  bool _isDownloadingModel = false;
  late final PremiumEntitlementController _entitlementController;
  late final AnimationController _swapButtonController;
  late final Animation<double> _swapIconTurn;

  Future<void> _handleModeChange(TranslateMode mode) async {
    if (mode == TranslateMode.basic) {
      setState(() => _mode = TranslateMode.basic);
      return;
    }

    setState(() => _isCheckingPremium = true);
    try {
      if (_entitlementController.state.status ==
          PremiumEntitlementStatus.loading) {
        await _entitlementController.refresh();
      }
      if (!mounted) return;
      _applyPremiumSelectionOutcome();
    } finally {
      if (mounted) setState(() => _isCheckingPremium = false);
    }
  }

  void _applyPremiumSelectionOutcome() {
    if (_entitlementController.canUsePremium) {
      setState(() => _mode = TranslateMode.premium);
      return;
    }
    setState(() => _mode = TranslateMode.basic);
    if (_entitlementController.state.isConfirmedInactive) {
      _showPremiumRequiredAndOpenUpgrade();
      return;
    }
    _showPremiumVerificationRetry();
  }

  void _showPremiumRequiredAndOpenUpgrade() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.ui(
              'A Premium account is required to use this feature.',
            ),
          ),
        ),
      );
    context.push('/profile/upgrade');
  }

  void _showPremiumVerificationRetry() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.ui('Unable to verify Premium right now.')),
          action: SnackBarAction(
            key: const Key('translate-premium-retry'),
            label: context.l10n.ui('Retry'),
            onPressed: () => unawaited(_retryPremiumSelection()),
          ),
        ),
      );
  }

  Future<void> _retryPremiumSelection() async {
    if (mounted) setState(() => _isCheckingPremium = true);
    try {
      await _entitlementController.retry();
      if (!mounted) return;
      _applyPremiumSelectionOutcome();
    } finally {
      if (mounted) setState(() => _isCheckingPremium = false);
    }
  }

  void _handleEntitlementChanged() {
    if (!mounted ||
        _mode != TranslateMode.premium ||
        _entitlementController.canUsePremium) {
      return;
    }
    setState(() => _mode = TranslateMode.basic);
  }

  @override
  void initState() {
    super.initState();
    _entitlementController =
        widget.entitlementController ?? PremiumEntitlementController.instance;
    _entitlementController.addListener(_handleEntitlementChanged);
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
    _entitlementController.removeListener(_handleEntitlementChanged);
    unawaited(_audioPlayer.dispose());
    unawaited(TtsService.instance.stop());
    _swapButtonController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _handleInputChanged(String value) {
    ++_translationRequestId;
    setState(() {
      _isTranslating = false;
      _isDownloadingModel = false;
      _translationError = null;
      _translatedText = '';
    });
  }

  void _markTranslationStale() {
    ++_translationRequestId;
    setState(() {
      _isTranslating = false;
      _isDownloadingModel = false;
      _translationError = null;
      _translatedText = '';
    });
  }

  void _requestTranslate({String? text}) {
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
    unawaited(_translate(value));
  }

  Future<void> _translate(String text) async {
    final int requestId = ++_translationRequestId;

    try {
      if (_mode == TranslateMode.basic) {
        if (_source.code == 'auto') {
          throw TranslationException(
            'Tính năng tự động nhận diện ngôn ngữ chỉ có ở bản Premium.',
          );
        }

        bool sourceReady = await OfflineTranslationService.instance
            .isModelDownloaded(_source.code);
        bool targetReady = await OfflineTranslationService.instance
            .isModelDownloaded(_target.code);

        if (!sourceReady || !targetReady) {
          if (!mounted || requestId != _translationRequestId) return;
          setState(() {
            _isDownloadingModel = true;
            _isTranslating = false;
          });
          await OfflineTranslationService.instance.downloadModel(_source.code);
          await OfflineTranslationService.instance.downloadModel(_target.code);
          if (!mounted || requestId != _translationRequestId) return;
          setState(() {
            _isDownloadingModel = false;
            _isTranslating = true;
          });
        }

        final String result = await OfflineTranslationService.instance
            .translate(text, _source.code, _target.code);

        if (!mounted || requestId != _translationRequestId) return;
        setState(() {
          _translatedText = result;
          _translationError = null;
          _isTranslating = false;
        });
      } else {
        final TranslationResult result = await _translationService.translate(
          text: text,
          sourceLanguageCode: _source.code,
          targetLanguageCode: _target.code,
          targetLanguageName: _target.name,
        );

        if (!mounted || requestId != _translationRequestId) return;

        setState(() {
          _translatedText = result.translatedText;
          _translationError = null;
          _isTranslating = false;
        });
      }
    } on TranslationException catch (error) {
      if (!mounted || requestId != _translationRequestId) {
        return;
      }

      setState(() {
        _translationError = error.message;
        _isTranslating = false;
        _isDownloadingModel = false;
      });
    } catch (_) {
      if (!mounted || requestId != _translationRequestId) {
        return;
      }

      setState(() {
        _translationError = 'Khong the dich luc nay. Vui long thu lai.';
        _isTranslating = false;
        _isDownloadingModel = false;
      });
    }
  }

  Future<void> _openLanguageSheet({required bool selectingSource}) async {
    final _LanguageOption? selected =
        await showModalBottomSheet<_LanguageOption>(
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

    _markTranslationStale();
  }

  void _swapLanguages() {
    _swapButtonController.forward(from: 0);
    if (_source.code == 'auto') {
      setState(() {
        _source = _allLanguages[2];
        _target = _allLanguages[1];
      });
      _markTranslationStale();
      return;
    }

    setState(() {
      final _LanguageOption temp = _source;
      _source = _target;
      _target = temp;
    });
    _markTranslationStale();
  }

  void _handleQuickExample(String value) {
    _inputController.text = value;
    _markTranslationStale();
  }

  Future<bool> _speakTranslatedText(String text, _LanguageOption target) async {
    if (_mode != TranslateMode.premium) {
      return TtsService.instance.speak(text, languageCode: target.code);
    }

    final OnlineSpeechResult speech = await _translationService
        .synthesizeSpeech(
          text: text,
          languageCode: target.code,
          languageName: target.name,
        );
    await TtsService.instance.stop();
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(speech.audioUrl));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              context.l10n.ui('Translate'),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 33,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _TranslateModeMenu(
                        mode: _mode,
                        isBusy: _isCheckingPremium,
                        onChanged: _handleModeChange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
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
                            onTap: () =>
                                _openLanguageSheet(selectingSource: true),
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
                            onTap: () =>
                                _openLanguageSheet(selectingSource: false),
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
                      isBusy: _isTranslating || _isDownloadingModel,
                      onChanged: _handleInputChanged,
                      onTranslate: _requestTranslate,
                      onClear: () {
                        _inputController.clear();
                        setState(() {
                          _translatedText = '';
                          _isTranslating = false;
                          _isDownloadingModel = false;
                          _translationError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _OutputCard(
                      target: _target,
                      translatedText: _translatedText,
                      isLoading: _isTranslating || _isDownloadingModel,
                      errorText: _translationError,
                      onSpeak: _speakTranslatedText,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.ui('QUICK EXAMPLES'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List<Widget>.generate(_quickExamples.length, (
                      int index,
                    ) {
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

class _TranslateModeMenu extends StatelessWidget {
  const _TranslateModeMenu({
    required this.mode,
    required this.isBusy,
    required this.onChanged,
  });

  final TranslateMode mode;
  final bool isBusy;
  final ValueChanged<TranslateMode> onChanged;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final bool isOffline = mode == TranslateMode.basic;
    final Color color = isOffline
        ? const Color(0xFF52606D)
        : const Color(0xFF2F8EE8);

    return PopupMenuButton<TranslateMode>(
      tooltip: 'Translation mode',
      initialValue: mode,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<TranslateMode>>[
        const PopupMenuItem<TranslateMode>(
          value: TranslateMode.basic,
          child: Row(
            children: <Widget>[
              Icon(Icons.offline_bolt_outlined, size: 18),
              SizedBox(width: 10),
              Text('Offline'),
            ],
          ),
        ),
        const PopupMenuItem<TranslateMode>(
          value: TranslateMode.premium,
          child: Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, size: 18),
              SizedBox(width: 10),
              Text('AI Premium'),
            ],
          ),
        ),
      ],
      child: Container(
        height: 40,
        constraints: const BoxConstraints(maxWidth: 122),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isOffline ? const Color(0xFFEAF5FF) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOffline
                ? const Color(0xFFAEDBFB)
                : const Color(0xFF8CC7FA),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isOffline
                  ? Icons.offline_bolt_outlined
                  : Icons.auto_awesome_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                isOffline ? 'Offline' : 'AI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: color),
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
            color: isSource ? const Color(0xFFAEDBFB) : const Color(0xFFC3ECCA),
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
    required this.isBusy,
    required this.onChanged,
    required this.onTranslate,
    required this.onClear,
  });

  final _LanguageOption source;
  final TextEditingController controller;
  final bool isBusy;
  final ValueChanged<String> onChanged;
  final VoidCallback onTranslate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final bool canTranslate = controller.text.trim().isNotEmpty && !isBusy;
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
              _RoundFlag(flagCode: source.flagCode, radius: 8),
              const SizedBox(width: 6),
              Text(
                source.name,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE1F6FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (controller.text.isNotEmpty) ...<Widget>[
                InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white,
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
            decoration: InputDecoration(
              hintText: context.l10n.ui('Enter text to translate...'),
              hintStyle: const TextStyle(
                fontSize: 16,
                color: Color(0xA0EAF7FF),
              ),
              border: InputBorder.none,
            ),
            cursorColor: Colors.white,
            style: const TextStyle(fontSize: 17, color: Colors.white),
          ),
          Row(
            children: <Widget>[
              Text(
                '${controller.text.length}/1000',
                style: const TextStyle(fontSize: 12, color: Color(0xDDEAF7FF)),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: canTranslate ? onTranslate : null,
                icon: isBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2FAFEF),
                          ),
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text(context.l10n.ui('Translate')),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  foregroundColor: const Color(0xFF2FAFEF),
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.28),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                  minimumSize: const Size(116, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  const _OutputCard({
    required this.target,
    required this.translatedText,
    required this.isLoading,
    required this.onSpeak,
    this.errorText,
  });

  final _LanguageOption target;
  final String translatedText;
  final bool isLoading;
  final Future<bool> Function(String text, _LanguageOption target) onSpeak;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.trim().isNotEmpty;
    final bool hasTranslation = translatedText.trim().isNotEmpty;
    final String bodyText = hasError
        ? errorText!
        : isLoading
        ? context.l10n.ui('Translating...')
        : hasTranslation
        ? translatedText
        : context.l10n.ui('Translation appears here');
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.l10n.ui('DONE'),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (hasTranslation) ...<Widget>[
                InkWell(
                  onTap: () async {
                    bool spoken = false;
                    String? errorMessage;
                    try {
                      spoken = await onSpeak(translatedText, target);
                    } on TranslationException catch (error) {
                      errorMessage = error.message;
                    } catch (_) {
                      errorMessage =
                          'Khong the phat giong doc luc nay. Vui long thu lai.';
                    }

                    if (!context.mounted || spoken) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          errorMessage ??
                              'Text-to-speech voice for ${target.name} is not available on this device.',
                        ),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.volume_up_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
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
              fontWeight: hasTranslation || isLoading || hasError
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
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            _RoundFlag(flagCode: language.flagCode, radius: 8),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
    final ThemeData theme = Theme.of(context);
    final List<_LanguageOption> options = widget.languages.where((
      _LanguageOption item,
    ) {
      if (!widget.allowAutoDetect && item.code == 'auto') return false;
      return item.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.74,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
                Expanded(
                  child: Text(
                    context.l10n.ui('Select Language'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                onChanged: (String value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: context.l10n.ui('Search language...'),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFB0B8C4),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEEF4FF)
                          : Colors.transparent,
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
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: selected
                                  ? const Color(0xFF2E74DA)
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF4B9AF4),
                          ),
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
                errorBuilder:
                    (
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
