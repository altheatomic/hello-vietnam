import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';

/// A styled search bar with a filter action button.
///
/// [onSearch] fires when the user submits text.
/// [onFilter] fires when the filter icon is tapped.
class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({
    super.key,
    this.controller,
    this.focusNode,
    this.onSearch,
    this.onChanged,
    this.onTap,
    this.onFilter,
    this.hintText = 'Search',
    this.autofocus = false,
    this.readOnly = false,
    this.showFilterButton = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onFilter;
  final String hintText;
  final bool autofocus;
  final bool readOnly;
  final bool showFilterButton;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color surfaceColor = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.92)
        : Colors.white;
    final Color textColor = theme.colorScheme.onSurface;
    final Color hintColor = isDark
        ? const Color(0xFFA9BCC7)
        : AppColors.textSecondary.withValues(alpha: 0.58);
    final Color shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.06);
    final BorderSide borderSide = BorderSide(
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : AppColors.primaryLight.withValues(alpha: 0.16),
    );

    return Row(
      children: [
        // ── Search field ────────────────────────────────
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(45),
              border: Border.fromBorderSide(borderSide),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              readOnly: readOnly,
              onTap: onTap,
              onChanged: onChanged,
              onSubmitted: onSearch,
              textInputAction: TextInputAction.search,
              showCursor: !readOnly,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: hintColor, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        if (showFilterButton) ...[
          const SizedBox(width: 10),

          // ── Filter button (white bg, blue icon) ─────────
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(45),
              border: Border.fromBorderSide(borderSide),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: onFilter,
              icon: Icon(
                Icons.tune_rounded,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
                size: 22,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
