import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';

/// A standard page scaffold used by non-Home screens.
///
/// Renders a sky-blue header block (matching Home) with a [title] and
/// optional [actions], then places [body] below it on [AppColors.background].
///
/// Pass [headerBottom] to add content (e.g. a search bar) inside the header.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.headerBottom,
    this.showBack = true,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  /// Extra widget rendered below the title row inside the blue header block.
  final Widget? headerBottom;

  /// Whether to show a back arrow when there is a previous route.
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final canPop = Navigator.of(context).canPop();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Blue header block (mirrors Home) ──────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const <Color>[
                        Color(0xFF0B2632),
                        Color(0xFF123A47),
                        Color(0xFF0D2F35),
                      ]
                    : const <Color>[
                        Color(0xFF69C9F1),
                        AppColors.primary,
                        Color(0xFF36D5C7),
                      ],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              statusBarHeight + 12,
              AppConstants.pagePadding,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (showBack && canPop)
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(
                            0xFFFFF176,
                          ), // yellow title, same as Home
                        ),
                      ),
                    ),
                    if (actions != null) ...actions!,
                  ],
                ),
                if (headerBottom != null) ...[
                  const SizedBox(height: 18),
                  headerBottom!,
                ],
              ],
            ),
          ),

          // ── Page body ────────────────────────────────────
          Expanded(child: body),
        ],
      ),
    );
  }
}
