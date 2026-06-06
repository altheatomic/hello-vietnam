import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';

class RecommendPage extends StatelessWidget {
  const RecommendPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top;
    final bottomInset = mediaQuery.padding.bottom;
    final headerHeight = (mediaQuery.size.height * 0.2).clamp(132.0, 176.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF2FBFF),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 34),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    height: headerHeight + topInset,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.topRight,
                        colors: [Color(0xFF18BCEB), Color(0xFF5A93F7)],
                      ),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(42),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppConstants.pagePadding,
                        topInset + 2,
                        AppConstants.pagePadding,
                        0,
                      ),
                      child: Row(
                        children: [
                          _HeaderCircleButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Text(
                              context.l10n.ui('Recommendation'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 52),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppConstants.pagePadding + 10,
                    right: AppConstants.pagePadding + 10,
                    bottom: -14,
                    child: _SearchPrompt(
                      onTap: () => context.push(AppRoutes.exploreSearch),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  AppConstants.pagePadding,
                  62,
                  AppConstants.pagePadding,
                  bottomInset + 32,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFF3FEFF),
                      const Color(0xFFE6F8FD),
                      Colors.white.withValues(alpha: 0.96),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(108),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.ui('Please choose: ✨'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2EB9F8),
                      ),
                    ),
                    const SizedBox(height: 36),
                    _RecommendImageCard(
                      assetPath: AppConstants.recommendWhereCardAsset,
                      label: context.l10n.ui('Where do\nyou want\nto go?'),
                      labelPadding: const EdgeInsets.fromLTRB(26, 18, 28, 18),
                      labelAlignment: Alignment.centerRight,
                      labelTextAlign: TextAlign.center,
                      onTap: () => context.push(AppRoutes.recommendWhereSearch),
                    ),
                    const SizedBox(height: 18),
                    _RecommendImageCard(
                      assetPath: AppConstants.recommendWhenCardAsset,
                      label: context.l10n.ui('When are\nyou free to\ntravel?'),
                      onTap: () =>
                          context.push(AppRoutes.recommendWhenCalendar),
                    ),
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

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Icon(icon, size: 28, color: const Color(0xFF4B5563)),
      ),
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFDDE7F8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF97A0B1),
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.ui('Search destinations'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF97A0B1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendImageCard extends StatelessWidget {
  const _RecommendImageCard({
    required this.assetPath,
    required this.label,
    required this.onTap,
    this.labelPadding = const EdgeInsets.fromLTRB(30, 28, 30, 28),
    this.labelAlignment = Alignment.centerLeft,
    this.labelTextAlign = TextAlign.left,
  });

  final String assetPath;
  final String label;
  final VoidCallback onTap;
  final EdgeInsets labelPadding;
  final Alignment labelAlignment;
  final TextAlign labelTextAlign;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 186,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
            image: DecorationImage(
              image: AssetImage(assetPath),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
            padding: labelPadding,
            child: Align(
              alignment: labelAlignment,
              child: Text(
                label,
                textAlign: labelTextAlign,
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
