import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ai_search_service.dart';

enum _AiSearchView { initial, analyzing, resultFood, resultObject }

class AiSearchPage extends StatefulWidget {
  const AiSearchPage({super.key});

  @override
  State<AiSearchPage> createState() => _AiSearchPageState();
}

class _AiSearchPageState extends State<AiSearchPage> {
  static const Color _accent = Color(0xFF29B6F6);
  static const Color _accentDark = Color(0xFF0277BD);
  static const Color _screenBg = Color(0xFFF7F9FC);
  static const Color _cardShadow1 = Color(0x14000000);
  static const Color _cardShadow2 = Color(0x0A000000);

  _AiSearchView _view = _AiSearchView.initial;
  bool _foodFavorite = false;
  bool _objectFavorite = false;
  final ImagePicker _imagePicker = ImagePicker();
  final AiSearchService _aiSearchService = AiSearchService();
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

  bool get _isActiveFavorite {
    return _activeRecognitionData.isFood ? _foodFavorite : _objectFavorite;
  }

  void _toggleFavorite() {
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
      final AiSearchResult result = await _aiSearchService.analyzeImage(file);
      if (!mounted) return;
      setState(() {
        _activeRecognitionData = _RecognitionData.fromAiSearchResult(result);
        _view = result.isFood
            ? _AiSearchView.resultFood
            : _AiSearchView.resultObject;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _view == _AiSearchView.initial
            ? _buildInitialView(context)
            : _view == _AiSearchView.analyzing
            ? _buildAnalyzingView(context)
            : _buildResultView(context, _activeData),
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
                'Snap or upload a photo to explore\nits origin and ingredients',
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
            color: const Color(0xFFF4F7FB),
            child: Padding(
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
                          const Text(
                            'Choose from Library',
                            style: TextStyle(
                              color: Color(0xFF0277BD),
                              fontSize: 30 / 2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'PNG, JPG supported',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
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
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
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

  Widget _buildResultView(BuildContext context, _RecognitionData data) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double bottomSafe = MediaQuery.of(context).padding.bottom;

    return Stack(
      key: ValueKey<String>('result_${data.categoryLabel}'),
      children: <Widget>[
        Positioned.fill(
          child: Container(
            color: _screenBg,
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
                                    data.isFood ? 'Food' : 'Object',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _favoriteButton(),
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
                        _buildMatchCard(data),
                        const SizedBox(height: 12),
                        if (data.isFood)
                          ..._buildFoodCards(data)
                        else
                          ..._buildObjectCards(data),
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

  List<Widget> _buildFoodCards(_RecognitionData data) {
    return <Widget>[
      _buildInfoCard(
        icon: Icons.restaurant_menu_rounded,
        title: 'MAIN INGREDIENTS',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: data.primaryTags.map(_buildPill).toList(),
        ),
      ),
      const SizedBox(height: 12),
      _buildInfoCard(
        icon: Icons.star_border_rounded,
        title: 'TASTE PROFILE',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: data.secondaryTags.map(_buildPill).toList(),
        ),
      ),
      const SizedBox(height: 12),
      _buildInfoCard(
        icon: Icons.access_time_rounded,
        title: 'BEST TIME TO ENJOY',
        child: Text(
          data.bestTime,
          style: const TextStyle(
            fontSize: 29 / 2.2,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(height: 12),
      _buildInfoCard(
        icon: Icons.info_outline_rounded,
        title: 'FOOD NOTE',
        child: Text(
          data.note,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF64748B),
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(height: 12),
      _buildInfoCard(
        icon: Icons.menu_book_rounded,
        title: 'CULTURAL SIGNIFICANCE',
        child: Text(
          data.cultural,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF64748B),
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(height: 12),
      _buildInfoCard(
        icon: Icons.place_outlined,
        title: 'SUGGESTED PLACES TO TRY',
        child: Column(children: data.places.map(_buildPlaceLine).toList()),
      ),
    ];
  }

  List<Widget> _buildObjectCards(_RecognitionData data) {
    return <Widget>[
      _buildInfoCard(
        icon: Icons.sell_outlined,
        title: 'CATEGORY',
        child: Wrap(children: <Widget>[_buildPill(data.categoryText)]),
      ),
      const SizedBox(height: 12),
      _buildInfoCard(
        icon: Icons.layers_outlined,
        title: 'MAIN MATERIALS',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: data.primaryTags.map(_buildPill).toList(),
        ),
      ),
      const SizedBox(height: 12),
      _buildInfoCard(
        icon: Icons.widgets_outlined,
        title: 'COMMON USAGE',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.usageBullets.map(_buildBulletLine).toList(),
        ),
      ),
      const SizedBox(height: 12),
      _buildInfoCard(
        icon: Icons.handyman_outlined,
        title: 'PRODUCTION METHOD',
        child: Text(
          data.productionMethod,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF64748B),
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(height: 12),
      _buildInfoCard(
        icon: Icons.circle_outlined,
        title: 'ALTERNATIVE NAMES',
        child: Text(
          data.alternativeNames,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF64748B),
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(height: 12),
      _buildInfoCard(
        icon: Icons.attach_money_rounded,
        title: 'PRICE RANGE',
        child: Text(
          data.priceRange,
          style: const TextStyle(
            fontSize: 13,
            color: _accentDark,
            height: 1.45,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 12),
      _buildInfoCard(
        icon: Icons.storefront_outlined,
        title: 'WHERE TO BUY / SEE IT',
        child: Column(children: data.places.map(_buildPlaceLine).toList()),
      ),
    ];
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
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
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 14, color: _accentDark),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildMatchCard(_RecognitionData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
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
              const Text(
                '|  AI Recognition Result',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.summary,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.26), width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: _accentDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBulletLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              color: _accentDark,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: _accentDark,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
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

  Widget _glassButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
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

  factory _RecognitionData.fromAiSearchResult(AiSearchResult result) {
    final double confidencePercent = result.confidence * 100;
    final bool highMatch = result.confidence >= 0.85;
    final bool mediumMatch = result.confidence >= 0.65;

    return _RecognitionData(
      isFood: result.isFood,
      matchLabel: highMatch
          ? 'High Match'
          : mediumMatch
          ? 'Possible Match'
          : 'Low Confidence',
      matchLabelColor: highMatch
          ? const Color(0xFF22C55E)
          : mediumMatch
          ? const Color(0xFFF59E0B)
          : const Color(0xFFEF4444),
      categoryLabel: result.isFood ? 'Food' : 'Object',
      location: result.locationHint.isNotEmpty
          ? result.locationHint
          : 'Vietnam',
      title: result.detectedName.isNotEmpty
          ? result.detectedName
          : (result.isFood ? 'Unknown dish' : 'Unknown object'),
      subtitle: result.subtitle.isNotEmpty
          ? result.subtitle
          : '${confidencePercent.toStringAsFixed(0)}% confidence',
      summary: result.summary.isNotEmpty
          ? result.summary
          : 'Gemini did not return a detailed summary for this image.',
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
    );
  }
}
