import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';

/// A styled search bar (full width, no filter button).
///
/// [onSearch] fires when the user submits text.
class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({
    super.key,
    this.onSearch,
    this.hintText = 'Search',
  });

  final ValueChanged<String>? onSearch;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
