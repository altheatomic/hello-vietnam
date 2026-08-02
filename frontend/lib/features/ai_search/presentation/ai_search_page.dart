import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/translate/data/openai_translation_service.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ai_recognition_history_repository.dart';
import '../data/ai_search_service.dart';
import '../application/ai_recognition_map_coordinator.dart';
import 'widgets/ai_recognition_result_sections.dart';

enum _AiSearchView { initial, analyzing, result }

enum _MapFallbackChoice { openSettings, continueWithoutLocation }

class AiSearchPage extends StatefulWidget {
  const AiSearchPage({
    super.key,
    this.aiSearchService,
    this.historyStore,
    this.onOpenHistory,
    this.initialHistoryEntry,
    this.mapCoordinator,
    this.onCopyText,
    this.onSpeakText,
  });

  final AiSearchService? aiSearchService;
  final AiRecognitionHistoryStore? historyStore;
  final VoidCallback? onOpenHistory;
  final AiRecognitionHistoryEntry? initialHistoryEntry;
  final AiRecognitionMapCoordinator? mapCoordinator;
  final Future<void> Function(String text)? onCopyText;
  final Future<void> Function(String text)? onSpeakText;

  @override
  State<AiSearchPage> createState() => _AiSearchPageState();
}

class _AiSearchPageState extends State<AiSearchPage> {
  static const Color _accent = Color(0xFF29B6F6);
  static const Color _accentDark = Color(0xFF0277BD);
  static const Color _cardShadow1 = Color(0x14000000);
  static const Color _cardShadow2 = Color(0x0A000000);

  _AiSearchView _view = _AiSearchView.initial;
  bool _foodFavorite = false;
  bool _objectFavorite = false;
  bool _openingMap = false;
  bool _speaking = false;
  final ImagePicker _imagePicker = ImagePicker();
  late final AiSearchService _aiSearchService;
  late final AiRecognitionHistoryStore _historyStore;
  late final AiRecognitionMapCoordinator _mapCoordinator;
  AiSearchResult? _activeResult;
  AudioPlayer? _audioPlayer;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  _RecognitionData _activeRecognitionData = const _RecognitionData(
    isFood: true,
    matchLabel: 'Possible Match',
    matchLabelColor: Color(0xFFF59E0B),
    categoryLabel: 'Food',
    location: 'Hanoi - Northern Vietnam',
    title: 'Bun Cha',
    subtitle: 'Bun Cha',
    summary:
        'Chargrilled pork patties and belly served with cold vermicelli noodles, fresh herbs, and a sweet-savory dipping sauce - a Hanoi lunchtime staple.',
    heroAssetPath: 'assets/images/homepage/bestdishes_bg.jpeg',
    primaryTags: <String>[
      'Vermicelli',
      'Pork Patty',
      'Pork Belly',
      'Fish Sauce',
      'Garlic',
      'Chili',
      'Papaya',
    ],
    secondaryTags: <String>['Savory', 'Sweet', 'Smoky'],
    bestTime: 'Lunch - 11am-2pm only at most stalls',
    note:
        'Contains pork and fish sauce. Not vegetarian. Mild spice level; extra chili available.',
    cultural:
        'Went globally viral after President Obama dined on it with Anthony Bourdain in 2016.',
    places: <String>[
      'Bun Cha Huong Lien - 24 Le Van Huu',
      'Bun Cha Dac Kim - 1 Hang Manh',
      'Old Quarter stalls',
    ],
  );

  _RecognitionData get _activeData => _activeRecognitionData;

  @override
  void initState() {
    super.initState();
    _aiSearchService = widget.aiSearchService ?? AiSearchService();
    _historyStore = widget.historyStore ?? AiRecognitionHistoryRepository();
    _mapCoordinator =
        widget.mapCoordinator ?? DefaultAiRecognitionMapCoordinator();
    final AiRecognitionHistoryEntry? historyEntry = widget.initialHistoryEntry;
    if (historyEntry != null) {
      _selectedImageBytes = historyEntry.thumbnailBytes;
      _activeResult = historyEntry.result;
      _activeRecognitionData = _RecognitionData.fromAiSearchResult(
        historyEntry.result,
      );
      _view = _AiSearchView.result;
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  bool get _isActiveFavorite {
    return _activeRecognitionData.isFood ? _foodFavorite : _objectFavorite;
  }

  bool get _canFavorite {
    final AiRecognitionKind? kind = _activeResult?.kind;
    return kind == AiRecognitionKind.food ||
        kind == AiRecognitionKind.landmark ||
        kind == AiRecognitionKind.culturalObject;
  }

  void _toggleFavorite() {
    if (!_canFavorite) return;
    setState(() {
      if (_activeRecognitionData.isFood) {
        _foodFavorite = !_foodFavorite;
      } else {
        _objectFavorite = !_objectFavorite;
      }
    });
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) return;

      final Uint8List bytes = await file.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
      });
      await _startAnalyzing(file);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.ui('Could not open image')}: $error'),
        ),
      );
    }
  }

  Future<void> _startAnalyzing(XFile file) async {
    if (_view == _AiSearchView.analyzing) return;
    setState(() {
      _view = _AiSearchView.analyzing;
    });

    try {
      final AiSearchResult result = await _aiSearchService.analyzeImage(
        file,
        targetLanguageCode: context.languageController.languageCode,
        targetLanguageName: context.languageController.language.englishName,
      );
      if (!mounted) return;
      setState(() {
        _activeResult = result;
        _activeRecognitionData = _RecognitionData.fromAiSearchResult(result);
        _view = _AiSearchView.result;
      });
      await _saveRecognitionHistory(result, file);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _view = _AiSearchView.initial;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _saveRecognitionHistory(
    AiSearchResult result,
    XFile file,
  ) async {
    if (!result.isHistoryEligible) return;
    try {
      final Uint8List bytes = _selectedImageBytes ?? await file.readAsBytes();
      await _historyStore.save(result: result, imageBytes: bytes);
    } catch (error, stackTrace) {
      debugPrint('Could not save AI recognition history: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.ui(
              'Recognition completed, but history could not be saved.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _copyText(String text) async {
    final String normalized = text.trim();
    if (normalized.isEmpty) return;
    try {
      final Future<void> Function(String text)? callback = widget.onCopyText;
      if (callback != null) {
        await callback(normalized);
      } else {
        await Clipboard.setData(ClipboardData(text: normalized));
      }
      if (!mounted || callback != null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not copy text: $error')));
    }
  }

  Future<void> _speakSignText(AiSearchResult result) async {
    final AiRecognitionTextAnalysis? text = result.textAnalysis;
    final String original = text?.originalText.trim() ?? '';
    if (original.isEmpty || _speaking) return;
    _speaking = true;
    try {
      final Future<void> Function(String text)? callback = widget.onSpeakText;
      if (callback != null) {
        await callback(original);
      } else {
        final AppLanguage language = AppLanguageScope.languageOf(context);
        final String languageCode =
            text?.detectedLanguageCode.trim().isNotEmpty == true
            ? text!.detectedLanguageCode.trim()
            : language.code;
        final String languageName =
            text?.detectedLanguageName.trim().isNotEmpty == true
            ? text!.detectedLanguageName.trim()
            : language.englishName;
        final OnlineSpeechResult speech = await OpenAITranslationService()
            .synthesizeSpeech(
              text: original,
              languageCode: languageCode,
              languageName: languageName,
            );
        _audioPlayer ??= AudioPlayer();
        await _audioPlayer!.play(UrlSource(speech.audioUrl));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not play audio: $error')));
    } finally {
      _speaking = false;
    }
  }

  Future<void> _openMap(AiSearchResult result) async {
    final String query = result.mapQuery.trim().isNotEmpty
        ? result.mapQuery.trim()
        : result.textAnalysis?.mapQuery.trim() ?? '';
    if (query.isEmpty || !result.canOpenMap) return;
    if (_openingMap) return;
    _openingMap = true;
    try {
      final AiRecognitionMapPreparation preparation = await _mapCoordinator
          .prepare();
      bool launched = false;
      switch (preparation) {
        case AiRecognitionMapReady(:final origin):
          launched = await _mapCoordinator.launch(query, origin: origin);
        case AiRecognitionMapWithoutOrigin():
          launched = await _mapCoordinator.launch(query);
        case AiRecognitionMapNeedsSettings(:final target):
          final _MapFallbackChoice? choice = await _showMapSettingsDialog(
            target,
          );
          if (choice == _MapFallbackChoice.openSettings) {
            await _mapCoordinator.openSettings(target);
            return;
          }
          if (choice == _MapFallbackChoice.continueWithoutLocation) {
            launched = await _mapCoordinator.launch(query);
          }
      }
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open Google Maps.'),
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () => _copyText(query),
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open map: $error')));
    } finally {
      _openingMap = false;
    }
  }

  Future<_MapFallbackChoice?> _showMapSettingsDialog(
    AiRecognitionMapSettingsTarget target,
  ) {
    return showDialog<_MapFallbackChoice>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.l10n.ui('Location access needed')),
        content: Text(
          target == AiRecognitionMapSettingsTarget.app
              ? 'Allow location access in Settings for directions, or continue with a text search.'
              : 'Turn on location services for directions, or continue with a text search.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ui('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(_MapFallbackChoice.continueWithoutLocation),
            child: Text(context.l10n.ui('Continue Without Location')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_MapFallbackChoice.openSettings),
            child: Text(context.l10n.ui('Open Settings')),
          ),
        ],
      ),
    );
  }

  void _openHistory() {
    final VoidCallback? callback = widget.onOpenHistory;
    if (callback != null) {
      callback();
      return;
    }
    context.push(AppRoutes.aiSearchHistory);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _view == _AiSearchView.initial
            ? _buildInitialView(context)
            : _view == _AiSearchView.analyzing
            ? _buildAnalyzingView(context)
            : _buildResultView(context, _activeResult, _activeData),
      ),
    );
  }

  Widget _buildInitialView(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return Column(
      key: const ValueKey<String>('initial'),
      children: <Widget>[
        Container(
          height: 302,
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(24, topPadding + 18, 24, 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF29B6F6), Color(0xFF0277BD)],
            ),
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  _glassButton(
                    icon: Icons.chevron_left,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'AI Recognition',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  _glassButton(
                    key: const Key('ai-search-history-button'),
                    icon: Icons.history_rounded,
                    onTap: _openHistory,
                    tooltip: 'Recognition history',
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Snap or upload a photo to explore\nfood, places, signs, and local context',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xCCEAF6FD),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: <Widget>[
                  GestureDetector(
                    onTap: () => _pickAndAnalyze(ImageSource.gallery),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _accent.withValues(alpha: 0.8),
                          width: 1,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            _accent.withValues(alpha: 0.08),
                            _accentDark.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: <Color>[
                                  Color(0xFF29B6F6),
                                  Color(0xFF0277BD),
                                ],
                              ),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x4F29B6F6),
                                  blurRadius: 20,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Choose from Library',
                            style: TextStyle(
                              color: Color(0xFF0277BD),
                              fontSize: 30 / 2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'PNG, JPG supported',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => _pickAndAnalyze(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 22),
                      label: const Text('Open Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 30 / 2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzingView(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return Container(
      key: const ValueKey<String>('analyzing'),
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF29B6F6), Color(0xFF0277BD)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, topPadding + 18, 24, 24),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                _glassButton(
                  icon: Icons.chevron_left,
                  onTap: () => setState(() => _view = _AiSearchView.initial),
                ),
                const SizedBox(width: 10),
                const Text(
                  'AI Recognition',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.95, end: 1.05),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              builder: (BuildContext context, double value, Widget? child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Analyzing image...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Identifying category, ingredients, and context',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xD9FFFFFF),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: Color(0x40FFFFFF),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(
    BuildContext context,
    AiSearchResult? result,
    _RecognitionData data,
  ) {
    final AiSearchResult activeResult = result!;
    final double topPadding = MediaQuery.of(context).padding.top;
    final double bottomSafe = MediaQuery.of(context).padding.bottom;

    return Stack(
      key: ValueKey<String>('result_${data.categoryLabel}'),
      children: <Widget>[
        Positioned.fill(
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomSafe + 118),
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: topPadding + 240,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        _selectedImageBytes != null
                            ? Image.memory(
                                _selectedImageBytes!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              )
                            : Image.asset(
                                data.heroAssetPath,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (
                                      BuildContext context,
                                      Object error,
                                      StackTrace? stackTrace,
                                    ) {
                                      return Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: <Color>[
                                              Color(0xFF5B6073),
                                              Color(0xFF202736),
                                            ],
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.image_not_supported,
                                            color: Colors.white70,
                                            size: 36,
                                          ),
                                        ),
                                      );
                                    },
                              ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0x14000000),
                                Color(0xA6000000),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: topPadding + 14,
                          right: 14,
                          child: Row(
                            children: <Widget>[
                              GestureDetector(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.32,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    data.categoryLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_canFavorite) _favoriteButton(),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.location_on_outlined,
                                    color: Color(0xB3FFFFFF),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    data.location,
                                    style: const TextStyle(
                                      color: Color(0xB3FFFFFF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              Text(
                                data.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34 / 1.7,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                data.subtitle,
                                style: const TextStyle(
                                  color: Color(0xA6FFFFFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_selectedImageName != null &&
                                  _selectedImageName!
                                      .trim()
                                      .isNotEmpty) ...<Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  _selectedImageName!,
                                  style: const TextStyle(
                                    color: Color(0x99FFFFFF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                    child: Column(
                      children: <Widget>[
                        if (activeResult.kind != AiRecognitionKind.unclear &&
                            activeResult.kind !=
                                AiRecognitionKind.unsupported &&
                            activeResult.kind != AiRecognitionKind.signText)
                          _buildMatchCard(data),
                        if (activeResult.kind == AiRecognitionKind.food &&
                            data.databaseMatch != null) ...<Widget>[
                          const SizedBox(height: 12),
                          _buildDatabaseMatchCard(data.databaseMatch!),
                        ],
                        const SizedBox(height: 12),
                        AiRecognitionResultSections(
                          result: activeResult,
                          onOpenMap: () => _openMap(activeResult),
                          onCopyOriginal: () => _copyText(
                            activeResult.textAnalysis?.originalText ?? '',
                          ),
                          onCopyTranslation: () => _copyText(
                            activeResult.textAnalysis?.translatedText ?? '',
                          ),
                          onListen: () => _speakSignText(activeResult),
                          onTakePhoto: () =>
                              _pickAndAnalyze(ImageSource.camera),
                          onChooseImage: () =>
                              _pickAndAnalyze(ImageSource.gallery),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: topPadding + 14,
          left: 14,
          child: _glassButton(
            icon: Icons.close,
            onTap: () => setState(() => _view = _AiSearchView.initial),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(_RecognitionData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: _cardShadow1, blurRadius: 3, offset: Offset(0, 1)),
          BoxShadow(color: _cardShadow2, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.check_circle_outline,
                color: data.matchLabelColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                data.matchLabel,
                style: TextStyle(
                  color: data.matchLabelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '|  AI Recognition Result',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.summary,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseMatchCard(AiSearchDatabaseMatch match) {
    final int matchPercent = (match.matchScore * 100).round().clamp(0, 100);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_outlined,
              color: _accentDark,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  match.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Travel database match · $matchPercent%',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View details',
            onPressed: () => _openDatabaseMatch(match),
            icon: const Icon(Icons.arrow_forward_rounded),
            color: _accentDark,
          ),
        ],
      ),
    );
  }

  void _openDatabaseMatch(AiSearchDatabaseMatch match) {
    if (match.category != 'food') return;
    final ItemDetailRequest request = ItemDetailRequest(
      id: match.id,
      name: match.name,
      category: DetailCategory.food,
      fallbackImagePath: match.imagePath,
    );
    context.push(
      AppRoutes.detailPathForCategory(DetailCategory.food),
      extra: request,
    );
  }

  Widget _favoriteButton() {
    final bool isFavorite = _isActiveFavorite;
    return GestureDetector(
      onTap: _toggleFavorite,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.32),
            width: 1,
          ),
        ),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite ? const Color(0xFFFF5E7D) : Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _glassButton({
    Key? key,
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final Widget button = GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

class _RecognitionData {
  const _RecognitionData({
    required this.isFood,
    required this.matchLabel,
    required this.matchLabelColor,
    required this.categoryLabel,
    required this.location,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.heroAssetPath,
    this.categoryText = '',
    this.primaryTags = const <String>[],
    this.secondaryTags = const <String>[],
    this.bestTime = '',
    this.note = '',
    this.cultural = '',
    this.usageBullets = const <String>[],
    this.productionMethod = '',
    this.alternativeNames = '',
    this.priceRange = '',
    this.places = const <String>[],
    this.databaseMatch,
  });

  final bool isFood;
  final String matchLabel;
  final Color matchLabelColor;
  final String categoryLabel;
  final String location;
  final String title;
  final String subtitle;
  final String summary;
  final String heroAssetPath;

  final String categoryText;
  final List<String> primaryTags;
  final List<String> secondaryTags;
  final String bestTime;
  final String note;
  final String cultural;
  final List<String> usageBullets;
  final String productionMethod;
  final String alternativeNames;
  final String priceRange;
  final List<String> places;
  final AiSearchDatabaseMatch? databaseMatch;

  factory _RecognitionData.fromAiSearchResult(AiSearchResult result) {
    final double confidencePercent = result.confidence * 100;
    final bool highMatch = result.confidence >= 0.8;
    final bool mediumMatch = result.confidence >= 0.55;
    final bool fallback =
        result.kind == AiRecognitionKind.unclear ||
        result.kind == AiRecognitionKind.unsupported;
    final String categoryLabel = switch (result.kind) {
      AiRecognitionKind.food => 'Food',
      AiRecognitionKind.landmark => 'Landmark',
      AiRecognitionKind.culturalObject => 'Cultural Object',
      AiRecognitionKind.signText => 'Street Sign',
      AiRecognitionKind.unclear => 'Unclear',
      AiRecognitionKind.unsupported => 'Not Supported',
    };
    final String fallbackTitle = switch (result.kind) {
      AiRecognitionKind.food => 'Food',
      AiRecognitionKind.landmark => 'Landmark',
      AiRecognitionKind.culturalObject => 'Cultural object',
      AiRecognitionKind.signText => 'Street sign',
      AiRecognitionKind.unclear => 'Could not recognize clearly',
      AiRecognitionKind.unsupported => 'Image type not supported',
    };

    return _RecognitionData(
      isFood: result.isFood,
      matchLabel: fallback
          ? (result.kind == AiRecognitionKind.unclear
                ? 'Could not recognize clearly'
                : 'Image type not supported')
          : highMatch
          ? 'High Match'
          : mediumMatch
          ? 'Possible Match'
          : 'Low Confidence',
      matchLabelColor: fallback
          ? const Color(0xFF94A3B8)
          : highMatch
          ? const Color(0xFF22C55E)
          : mediumMatch
          ? const Color(0xFFF59E0B)
          : const Color(0xFFEF4444),
      categoryLabel: categoryLabel,
      location: result.locationHint.isNotEmpty
          ? result.locationHint
          : (fallback ? 'AI Recognition' : 'Vietnam'),
      title: result.detectedName.isNotEmpty
          ? result.detectedName
          : fallbackTitle,
      subtitle: result.subtitle.isNotEmpty
          ? result.subtitle
          : '${confidencePercent.toStringAsFixed(0)}% confidence',
      summary: result.summary.isNotEmpty ? result.summary : '',
      heroAssetPath: result.isFood
          ? 'assets/images/homepage/bestdishes_bg.jpeg'
          : 'assets/images/avatar/avatar.jpg',
      categoryText: result.categoryText,
      primaryTags: result.primaryTags,
      secondaryTags: result.secondaryTags,
      bestTime: result.bestTime,
      note: result.note,
      cultural: result.culturalSignificance,
      usageBullets: result.usageBullets,
      productionMethod: result.productionMethod,
      alternativeNames: result.alternativeNames,
      priceRange: result.priceRange,
      places: result.suggestedPlaces,
      databaseMatch: result.databaseMatch,
    );
  }
}
