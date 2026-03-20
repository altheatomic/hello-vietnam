import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import '../../domain/admin_user.dart';

/// Search + status-filter row for admin list pages.
///
/// Layout:  [Search pill — fixed 300 px]  ·····Spacer·····  [All] [Active] [Banned]
///
/// The search field sits on the left at a fixed desktop width; filter chips
/// are pushed to the right via Spacer. This matches the target layout where
/// search and filters are visually separated rather than tightly grouped.
///
/// Search pill rules inherited from SearchBarWidget:
///   radius 45 · white fill · divider border · shadow · primary icon.
///
/// Filter chips: flat pill — solid primary when selected, white with divider
/// border when unselected. No BoxShadow so the bar feels lighter than the
/// table card below it.
class AdminSearchFilterBar extends StatelessWidget {
  const AdminSearchFilterBar({
    super.key,
    required this.controller,
    required this.filterStatus,
    required this.onFilterStatusChanged,
    this.onSearchChanged,
  });

  final TextEditingController controller;
  final AdminUserStatus? filterStatus;
  final ValueChanged<AdminUserStatus?> onFilterStatusChanged;
  final ValueChanged<String>? onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search — fixed width so chips are always right-aligned
        SizedBox(
          width: 300,
          child: _SearchPill(
            controller: controller,
            onChanged: onSearchChanged,
          ),
        ),

        const Spacer(),

        _FilterChip(
          label: 'All',
          isSelected: filterStatus == null,
          onTap: () => onFilterStatusChanged(null),
        ),
        const SizedBox(width: 6),
        _FilterChip(
          label: 'Active',
          isSelected: filterStatus == AdminUserStatus.active,
          onTap: () => onFilterStatusChanged(
            filterStatus == AdminUserStatus.active ? null : AdminUserStatus.active,
          ),
        ),
        const SizedBox(width: 6),
        _FilterChip(
          label: 'Banned',
          isSelected: filterStatus == AdminUserStatus.banned,
          onTap: () => onFilterStatusChanged(
            filterStatus == AdminUserStatus.banned ? null : AdminUserStatus.banned,
          ),
        ),
      ],
    );
  }
}

// ── Search pill ──────────────────────────────────────────────────────────────

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(45),
        // Divider border matches the topbar search field for consistency
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search by name, email or ID…',
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  onPressed: controller.clear,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ── Status filter chip ───────────────────────────────────────────────────────

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.defaultAnimation,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            // Selected: solid primary — matches active FeatureGrid icon container.
            // Unselected: flat white with divider border — no shadow, clean.
            color: widget.isSelected
                ? AppColors.primary
                : _hovered
                    ? AppColors.primaryLight.withValues(alpha: 0.12)
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            border: widget.isSelected
                ? null
                : Border.all(color: AppColors.divider),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: widget.isSelected
                  ? AppColors.textOnPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
