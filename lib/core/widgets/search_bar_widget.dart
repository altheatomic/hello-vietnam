import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';

/// A styled search bar with a filter action button.
///
/// [onSearch] fires when the user submits text.
/// [onFilter] fires when the filter icon is tapped.
class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({
    super.key,
    this.onSearch,
    this.onFilter,
    this.hintText = 'Search',
  });

  final ValueChanged<String>? onSearch;
  final VoidCallback? onFilter;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Search field ────────────────────────────────
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(45),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onSubmitted: onSearch,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // ── Filter button (white bg, blue icon) ─────────
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(45),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onFilter,
            icon: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
          ),
        ),
      ],
    );
  }
}
