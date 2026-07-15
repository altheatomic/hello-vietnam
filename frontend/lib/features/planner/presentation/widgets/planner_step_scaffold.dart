import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';

class PlannerStepScaffold extends StatelessWidget {
  const PlannerStepScaffold({
    super.key,
    required this.currentStep,
    required this.badgeIcon,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.body,
    this.bodySlivers = const <Widget>[],
    this.stickyBodyHeader,
    this.stickyBodyHeaderExtent = 76,
    this.onNext,
    this.nextEnabled = false,
    this.nextLabel = 'Next',
  }) : assert(body != null || bodySlivers.length > 0);

  final int currentStep;
  final IconData badgeIcon;
  final String title;
  final String subtitle;
  final Widget? body;
  final List<Widget> bodySlivers;
  final Widget? stickyBodyHeader;
  final double stickyBodyHeaderExtent;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final bool nextEnabled;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF1F6FE),
              Color(0xFFDFF5FF),
              Color(0xFFCCF6F1),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            const Positioned(
              top: -90,
              right: -60,
              child: _DecorativeOrb(size: 220, color: Color(0x662BC3FF)),
            ),
            const Positioned(
              bottom: 110,
              left: -50,
              child: _DecorativeOrb(size: 180, color: Color(0x5556E2D5)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool tight = constraints.maxHeight < 720;
                  final double headerSize = tight ? 25 : 27;
                  final double subtitleSize = tight ? 14.5 : 15.5;
                  final double badgeSize = tight ? 68 : 78;
                  final double badgeIconSize = tight ? 30 : 34;
                  final double questionSize = tight ? 21 : 23;
                  final double questionSubtitleSize = tight ? 15 : 16;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      tight ? 6 : 10,
                      16,
                      tight ? 12 : 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _BackArrowButton(onTap: onBack),
                        ),
                        SizedBox(height: tight ? 10 : 14),
                        Text(
                          'Personalized Itinerary',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: headerSize,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.08,
                          ),
                        ),
                        SizedBox(height: tight ? 6 : 8),
                        Text(
                          "Let's create your perfect trip",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: subtitleSize,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF687384),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: tight ? 18 : 22),
                        _PlannerProgressBar(
                          currentStep: currentStep,
                          labelSize: tight ? 14 : 15,
                        ),
                        SizedBox(height: tight ? 10 : 12),
                        Expanded(
                          child: CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: <Widget>[
                              SliverToBoxAdapter(
                                child: _PlannerStepQuestionHeader(
                                  badgeIcon: badgeIcon,
                                  badgeSize: badgeSize,
                                  badgeIconSize: badgeIconSize,
                                  title: title,
                                  subtitle: subtitle,
                                  titleSize: questionSize,
                                  subtitleSize: questionSubtitleSize,
                                  compact: tight,
                                ),
                              ),
                              if (stickyBodyHeader != null)
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _StickyBodyHeaderDelegate(
                                    extent: stickyBodyHeaderExtent,
                                    child: stickyBodyHeader!,
                                  ),
                                ),
                              if (bodySlivers.isNotEmpty)
                                ...bodySlivers
                              else
                                SliverToBoxAdapter(child: body!),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 8),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: tight ? 10 : 14),
                        Row(
                          children: <Widget>[
                            Expanded(child: _PlannerBackButton(onTap: onBack)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _PlannerNextButton(
                                label: nextLabel,
                                enabled: nextEnabled,
                                onTap: onNext,
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _PlannerStepQuestionHeader extends StatelessWidget {
  const _PlannerStepQuestionHeader({
    required this.badgeIcon,
    required this.badgeSize,
    required this.badgeIconSize,
    required this.title,
    required this.subtitle,
    required this.titleSize,
    required this.subtitleSize,
    required this.compact,
  });

  final IconData badgeIcon;
  final double badgeSize;
  final double badgeIconSize;
  final String title;
  final String subtitle;
  final double titleSize;
  final double subtitleSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: compact ? 6 : 10,
        bottom: compact ? 16 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _BadgeIcon(icon: badgeIcon, size: badgeSize, iconSize: badgeIconSize),
          SizedBox(height: compact ? 18 : 22),
          Text(
            title,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: subtitleSize,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF6F7B8A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyBodyHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StickyBodyHeaderDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFF1F6FE),
            Color(0xFFDFF5FF),
            Color(0xFFCCF6F1),
          ],
        ),
      ),
      child: Padding(padding: const EdgeInsets.only(bottom: 16), child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyBodyHeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent || child != oldDelegate.child;
  }
}

class _PlannerProgressBar extends StatelessWidget {
  const _PlannerProgressBar({
    required this.currentStep,
    required this.labelSize,
  });

  final int currentStep;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: List<Widget>.generate(5, (int index) {
            final bool active = index < currentStep;
            return Expanded(
              child: Container(
                height: 8,
                margin: EdgeInsets.only(right: index == 4 ? 0 : 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: active
                      ? const LinearGradient(
                          colors: <Color>[Color(0xFF12C1E8), Color(0xFF449AF5)],
                        )
                      : null,
                  color: active ? null : const Color(0xFFD7D5DD),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Step $currentStep of 5',
          style: TextStyle(
            fontSize: labelSize,
            fontStyle: FontStyle.italic,
            color: const Color(0xFF7A8494),
          ),
        ),
      ],
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Container(
        width: size,
        height: size,
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
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Icon(icon, size: iconSize, color: Colors.white),
      ),
    );
  }
}

class _PlannerBackButton extends StatelessWidget {
  const _PlannerBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF2DB8F5), width: 2),
          color: Colors.white.withValues(alpha: 0.72),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x1A2DB8F5),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: const Center(
              child: Text(
                'Back',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2DB8F5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannerNextButton extends StatelessWidget {
  const _PlannerNextButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: enabled
              ? const LinearGradient(
                  colors: <Color>[Color(0xFF21B8F0), Color(0xFF359EF3)],
                )
              : null,
          color: enabled ? null : Colors.white.withValues(alpha: 0.72),
          border: Border.all(
            color: enabled ? Colors.transparent : const Color(0xFFD1CFD8),
            width: 1.6,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x17000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(24),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : const Color(0xFFA7AAB5),
                ),
              ),
            ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.74),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onBackPressed(onTap),
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF3A465D),
            ),
          ),
        ),
      ),
    );
  }

  VoidCallback onBackPressed(VoidCallback callback) => callback;
}

class _DecorativeOrb extends StatelessWidget {
  const _DecorativeOrb({required this.size, required this.color});

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
