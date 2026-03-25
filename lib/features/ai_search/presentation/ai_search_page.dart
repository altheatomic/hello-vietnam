import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum _AiSearchView {
  initial,
  analyzing,
  resultFood,
  resultObject,
}

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
  _AiSearchView _pendingResultView = _AiSearchView.resultFood;
  bool _foodFavorite = false;
  bool _objectFavorite = false;

  final _RecognitionData _foodData = const _RecognitionData(
    isFood: true,
    matchLabel: 'Possible Match',
    matchLabelColor: Color(0xFFF59E0B),
    categoryLabel: 'Food',
    location: 'Hanoi - Northern Vietnam',
    title: 'Bun Cha',
    subtitle: 'Bun Cha',
    summary:
        'Chargrilled pork patties and belly served with cold vermicelli noodles, fresh herbs, and a sweet-savory dipping sauce - a Hanoi lunchtime staple.',
    heroAssetPath: 'assets/images/dishes/banh_mi.jpg',
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

  final _RecognitionData _objectData = const _RecognitionData(
    isFood: false,
    matchLabel: 'High Match',
    matchLabelColor: Color(0xFF22C55E),
    categoryLabel: 'Object',
    location: 'Hue - Central Vietnam',
    title: 'Conical Hat',
    subtitle: 'Non La',
    summary:
        'A traditional Vietnamese palm-leaf cone hat worn for sun and rain protection, and a beloved cultural symbol of Vietnamese femininity.',
    heroAssetPath: 'assets/images/avatar/avatar.jpg',
    categoryText: 'Clothing / Craft',
    primaryTags: <String>[
      'Palm Leaves',
      'Bamboo Frame',
      'Nylon Thread',
      'Lacquer Coating',
    ],
    usageBullets: <String>[
      'Daily sun & rain protection',
      'Traditional festival attire',
      'Cultural souvenir',
      'Stage costume with Ao Dai',
    ],
    productionMethod: 'Handmade - each hat takes 1-2 days by skilled artisans',
    alternativeNames: 'Non Bai Tho (poem hat), Non Quai Thao (Northern style)',
    priceRange:
        '\$2 - \$15 USD (souvenir grade); \$20-\$50 USD (fine craft grade)',
    places: <String>[
      'Chuong Craft Village - Hanoi',
      'Dong Ba Market - Hue',
      'Hoi An Ancient Town',
      'Airport souvenir shops',
    ],
  );

  _RecognitionData get _activeData {
    return _view == _AiSearchView.resultObject ? _objectData : _foodData;
  }

  bool get _isActiveFavorite {
    return _view == _AiSearchView.resultObject
        ? _objectFavorite
        : _foodFavorite;
  }

  void _openFoodResult() {
    _startAnalyzingThenOpen(_AiSearchView.resultFood);
  }

  void _switchType() {
    setState(() {
      _view = _view == _AiSearchView.resultFood
          ? _AiSearchView.resultObject
          : _AiSearchView.resultFood;
    });
  }

  void _toggleFavorite() {
    setState(() {
      if (_view == _AiSearchView.resultObject) {
        _objectFavorite = !_objectFavorite;
      } else {
        _foodFavorite = !_foodFavorite;
      }
    });
  }

  Future<void> _startAnalyzingThenOpen(_AiSearchView targetView) async {
    if (_view == _AiSearchView.analyzing) return;
    setState(() {
      _pendingResultView = targetView;
      _view = _AiSearchView.analyzing;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _view = _pendingResultView;
    });
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
                    onTap: _openFoodResult,
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
                      onPressed: () =>
                          _startAnalyzingThenOpen(_AiSearchView.resultFood),
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
                return Transform.scale(
                  scale: value,
                  child: child,
                );
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
                        Image.asset(
                          data.heroAssetPath,
                          fit: BoxFit.cover,
                          errorBuilder: (
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
                                child: Icon(Icons.image_not_supported, color: Colors.white70, size: 36),
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
                                onTap: _switchType,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.32),
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
                        if (data.isFood) ..._buildFoodCards(data) else ..._buildObjectCards(data),
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
        child: Column(
          children: data.places.map(_buildPlaceLine).toList(),
        ),
      ),
    ];
  }

  List<Widget> _buildObjectCards(_RecognitionData data) {
    return <Widget>[
      _buildInfoCard(
        icon: Icons.sell_outlined,
        title: 'CATEGORY',
        child: Wrap(
          children: <Widget>[_buildPill(data.categoryText)],
        ),
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
        child: Column(
          children: data.places.map(_buildPlaceLine).toList(),
        ),
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
          BoxShadow(
            color: _cardShadow1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: _cardShadow2,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
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
                child: Icon(
                  icon,
                  size: 14,
                  color: _accentDark,
                ),
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
              Icon(Icons.check_circle_outline, color: data.matchLabelColor, size: 16),
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

  Widget _glassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
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
}
