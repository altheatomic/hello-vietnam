import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';

class TripPlannerPage extends StatefulWidget {
  const TripPlannerPage({super.key});

  @override
  State<TripPlannerPage> createState() => _TripPlannerPageState();
}

class _TripPlannerPageState extends State<TripPlannerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  void _handleTripTypeTap(String tripType) {
    if (tripType == 'Leisure') {
      context.push(AppRoutes.tripPlannerLocation);
      return;
    }
    context.push(AppRoutes.tripPlannerBusinessLocation);
  }

  void _handleSavedTripsTap() {
    context.push(AppRoutes.tripPlannerSaved);
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<Color> backgroundColors = isDark
        ? const <Color>[Color(0xFF020B10), Color(0xFF0B1A22), Color(0xFF0B2426)]
        : const <Color>[
            Color(0xFFF1F6FE),
            Color(0xFFDFF5FF),
            Color(0xFFCCF6F1),
          ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: backgroundColors,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -80,
              right: -60,
              child: _DecorativeBlurOrb(
                size: 220,
                color: isDark
                    ? const Color(0x332BC3FF)
                    : const Color(0x662BC3FF),
              ),
            ),
            Positioned(
              top: size.height * 0.28,
              left: -70,
              child: _DecorativeBlurOrb(
                size: 180,
                color: isDark
                    ? const Color(0x2232D2FF)
                    : const Color(0x5532D2FF),
              ),
            ),
            Positioned(
              bottom: 120,
              right: -50,
              child: _DecorativeBlurOrb(
                size: 170,
                color: isDark
                    ? const Color(0x2256E2D5)
                    : const Color(0x5556E2D5),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool tight = constraints.maxHeight < 700;
                  final bool compact = constraints.maxHeight < 780;

                  final double headerTitleSize = tight
                      ? 26
                      : (compact ? 28 : 30);
                  final double headerSubtitleSize = tight ? 15 : 16;
                  final double sectionTitleSize = tight ? 22 : 24;
                  final double sectionSubtitleSize = tight ? 14 : 15;
                  final double badgeSize = tight ? 66 : (compact ? 74 : 82);
                  final double badgeIconSize = tight ? 28 : (compact ? 31 : 34);

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      tight ? 2 : 6,
                      16,
                      tight ? 10 : 14,
                    ),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _controller,
                        curve: Curves.easeOutCubic,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _StaggeredEntrance(
                            controller: _controller,
                            begin: 0.0,
                            end: 0.28,
                            child: Row(
                              children: <Widget>[
                                _BackArrowButton(onTap: _handleBack),
                                const Spacer(),
                                _SavedTripsShortcutButton(
                                  onTap: _handleSavedTripsTap,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: tight ? 8 : 12),
                          _StaggeredEntrance(
                            controller: _controller,
                            begin: 0.08,
                            end: 0.38,
                            child: Text(
                              context.l10n.ui('Personalized Itinerary'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: headerTitleSize,
                                fontWeight: FontWeight.w800,
                                height: 1.08,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          SizedBox(height: tight ? 6 : 8),
                          _StaggeredEntrance(
                            controller: _controller,
                            begin: 0.16,
                            end: 0.46,
                            child: Text(
                              context.l10n.ui("Let's create your perfect trip"),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: headerSubtitleSize,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SizedBox(height: tight ? 14 : 18),
                          _StaggeredEntrance(
                            controller: _controller,
                            begin: 0.22,
                            end: 0.52,
                            child: _ProgressHeader(
                              barHeight: tight ? 8 : 10,
                              barGap: tight ? 8 : 10,
                              labelSize: tight ? 14 : 15,
                            ),
                          ),
                          SizedBox(height: tight ? 14 : 18),
                          _StaggeredEntrance(
                            controller: _controller,
                            begin: 0.3,
                            end: 0.6,
                            child: _PlannerIconBadge(
                              size: badgeSize,
                              iconSize: badgeIconSize,
                            ),
                          ),
                          SizedBox(height: tight ? 10 : 12),
                          _StaggeredEntrance(
                            controller: _controller,
                            begin: 0.36,
                            end: 0.66,
                            child: Text(
                              context.l10n.ui('Trip Type'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: sectionTitleSize,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          _StaggeredEntrance(
                            controller: _controller,
                            begin: 0.42,
                            end: 0.72,
                            child: Text(
                              context.l10n.ui(
                                'What type of trip are you planning?',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: sectionSubtitleSize,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SizedBox(height: tight ? 12 : 16),
                          Expanded(
                            child: Column(
                              children: <Widget>[
                                Expanded(
                                  child: _StaggeredEntrance(
                                    controller: _controller,
                                    begin: 0.5,
                                    end: 0.84,
                                    offset: const Offset(-0.08, 0),
                                    child: _TripTypeCard(
                                      title: context.l10n.ui('Leisure Trip'),
                                      subtitle: context.l10n.ui(
                                        'Relax, explore, and enjoy\nyour vacation',
                                      ),
                                      icon: Icons.beach_access_rounded,
                                      // Was Image.network() to a hardcoded
                                      // Unsplash URL — made this card depend
                                      // on network at build time, which
                                      // preload: true (router.dart) now
                                      // triggers as soon as the app starts
                                      // instead of only when the user opens
                                      // this tab. Same hue family as the old
                                      // overlayGradient below, just opaque,
                                      // so the card keeps its "beach" mood
                                      // with zero network dependency — see
                                      // _TripTypeCard's background Container.
                                      baseGradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: <Color>[
                                          Color(0xFF55C8FF),
                                          Color(0xFF39C6FF),
                                          Color(0xFF33D8C9),
                                        ],
                                      ),
                                      overlayGradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: <Color>[
                                          Color(0x6655C8FF),
                                          Color(0x6639C6FF),
                                          Color(0x6633D8C9),
                                        ],
                                      ),
                                      compact: compact,
                                      tight: tight,
                                      onTap: () =>
                                          _handleTripTypeTap('Leisure'),
                                    ),
                                  ),
                                ),
                                SizedBox(height: tight ? 10 : 12),
                                Expanded(
                                  child: _StaggeredEntrance(
                                    controller: _controller,
                                    begin: 0.58,
                                    end: 0.92,
                                    offset: const Offset(-0.08, 0),
                                    child: _TripTypeCard(
                                      title: context.l10n.ui('Business Trip'),
                                      subtitle: context.l10n.ui(
                                        'Meetings, conferences, and\nnetworking',
                                      ),
                                      icon: Icons.work_outline_rounded,
                                      // Same rationale as the Leisure card
                                      // above — opaque version of the old
                                      // overlayGradient's hue family instead
                                      // of a hardcoded Unsplash Image.network().
                                      baseGradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: <Color>[
                                          Color(0xFF899CFF),
                                          Color(0xFFA685FF),
                                          Color(0xFFB184FF),
                                        ],
                                      ),
                                      overlayGradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: <Color>[
                                          Color(0x66899CFF),
                                          Color(0x66A685FF),
                                          Color(0x66B184FF),
                                        ],
                                      ),
                                      compact: compact,
                                      tight: tight,
                                      onTap: () =>
                                          _handleTripTypeTap('Business'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.barHeight,
    required this.barGap,
    required this.labelSize,
  });

  final double barHeight;
  final double barGap;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Column(
      children: <Widget>[
        Row(
          children: List<Widget>.generate(5, (int index) {
            final bool isActive = index == 0;
            return Expanded(
              child: Container(
                height: barHeight,
                margin: EdgeInsets.only(right: index == 4 ? 0 : barGap),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: isActive
                      ? const LinearGradient(
                          colors: <Color>[Color(0xFF14C4E7), Color(0xFF4D9AF6)],
                        )
                      : null,
                  color: isActive
                      ? null
                      : (isDark
                            ? theme.colorScheme.surfaceContainerHighest
                            : const Color(0xFFD6D4DC)),
                  boxShadow: isActive
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x3319CFE8),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.stepOf(1, 5),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: labelSize,
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PlannerIconBadge extends StatelessWidget {
  const _PlannerIconBadge({required this.size, required this.iconSize});

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF21B8F0), Color(0xFF359EF3)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x5530DBD8),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.airplanemode_active_rounded,
        size: iconSize,
        color: Colors.white,
      ),
    );
  }
}

class _TripTypeCard extends StatefulWidget {
  const _TripTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.baseGradient,
    required this.overlayGradient,
    required this.compact,
    required this.tight,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  // Opaque hero background — replaces a former Image.network() to a
  // hardcoded Unsplash URL (made this card depend on network at build
  // time; broke once preload: true in router.dart made TripPlannerPage
  // build eagerly at app startup instead of only when the user opens this
  // tab — see trip_planner_page.dart's 2 call sites for the rationale).
  final Gradient baseGradient;
  final Gradient overlayGradient;
  final bool compact;
  final bool tight;
  final VoidCallback onTap;

  @override
  State<_TripTypeCard> createState() => _TripTypeCardState();
}

class _TripTypeCardState extends State<_TripTypeCard> {
  double _scale = 1;

  void _setScale(double value) {
    if (_scale == value) return;
    setState(() {
      _scale = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double cardPadding = widget.tight ? 14 : 18;
    final double titleSize = widget.tight ? 21 : (widget.compact ? 23 : 24);
    final double subtitleSize = widget.tight ? 13.5 : 14.5;
    final double iconBubbleSize = widget.tight
        ? 56
        : (widget.compact ? 62 : 68);
    final double iconSize = widget.tight ? 26 : 28;

    return GestureDetector(
      onTapDown: (_) => _setScale(0.985),
      onTapUp: (_) => _setScale(1),
      onTapCancel: () => _setScale(1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x163B4B75),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: widget.baseGradient),
                    child: Center(
                      // Large, low-opacity icon watermark — same "gradient +
                      // centered icon" placeholder language already used
                      // elsewhere in the app for image-less cards (see
                      // trip_location_page.dart's _PlaceholderBackground).
                      child: Icon(
                        widget.icon,
                        size: widget.tight ? 96 : 120,
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: widget.overlayGradient),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.04),
                          Colors.white.withValues(alpha: 0.12),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(cardPadding),
                    child: Row(
                      children: <Widget>[
                        _FrostedIconCircle(
                          icon: widget.icon,
                          size: iconBubbleSize,
                          iconSize: iconSize,
                        ),
                        SizedBox(width: widget.tight ? 12 : 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.05,
                                ),
                              ),
                              SizedBox(height: widget.tight ? 6 : 8),
                              Text(
                                widget.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: subtitleSize,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FrostedIconCircle extends StatelessWidget {
  const _FrostedIconCircle({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.42),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.1,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, size: iconSize, color: const Color(0xFF2CB6EE)),
        ),
      ),
    );
  }
}

class _SavedTripsShortcutButton extends StatelessWidget {
  const _SavedTripsShortcutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 1.2,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x120F2C4F),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.bookmark_added_rounded,
                size: 18,
                color: Color(0xFF21B4EB),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.ui('Saved Trips'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackArrowButton extends StatelessWidget {
  const _BackArrowButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 24,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _DecorativeBlurOrb extends StatelessWidget {
  const _DecorativeBlurOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color,
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.02),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaggeredEntrance extends StatelessWidget {
  const _StaggeredEntrance({
    required this.controller,
    required this.begin,
    required this.end,
    required this.child,
    this.offset = const Offset(0, 0.08),
  });

  final AnimationController controller;
  final double begin;
  final double end;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation animation = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double value = animation.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              offset.dx * (1 - value) * 50,
              offset.dy * (1 - value) * 50,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
