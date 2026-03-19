import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import '../../domain/admin_user.dart';

/// Search + status-filter row for admin list pages.
///
/// Layout:  [Search pill ────────────────] [All] [Active] [Banned]
///
/// Search pill visual rules are inherited from SearchBarWidget:
///   radius 45 · white fill · shadow (black 6 %, blur 8) · primary search icon
///   · textSecondary hint at 50 % · clear button when text is present.
///
/// Status chips use AppConstants.buttonRadius (12 px) and transition smoothly
/// via AppConstants.defaultAnimation — same as the sidebar nav items.
///
/// All state (query text + selected filter) lives in the parent page so that
/// filtering logic stays in one place and the bar remains stateless.
class AdminSearchFilterBar extends StatelessWidget {
  const AdminSearchFilterBar({
    super.key,
    required this.controller,
    required this.filterStatus,
    required this.onFilterStatusChanged,
    this.onSearchChanged,
  });

  final TextEditingController controller;

  /// Currently active status filter. Null means "show all".
  final AdminUserStatus? filterStatus;

  final ValueChanged<AdminUserStatus?> onFilterStatusChanged;

  /// Called on every keystroke so the parent can call setState.
  final ValueChanged<String>? onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Search pill ─────────────────────────────────────────
        Expanded(
          child: _SearchPill(
            controller: controller,
            onChanged: onSearchChanged,
          ),
        ),

        const SizedBox(width: 12),

        // ── Status filter chips ──────────────────────────────────
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
            filterStatus == AdminUserStatus.active
                ? null
                : AdminUserStatus.active,
          ),
        ),
        const SizedBox(width: 6),
        _FilterChip(
          label: 'Banned',
          isSelected: filterStatus == AdminUserStatus.banned,
          onTap: () => onFilterStatusChanged(
            filterStatus == AdminUserStatus.banned
                ? null
                : AdminUserStatus.banned,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
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
          // Clear button — only visible when there is text.
          // Evaluated at build time; parent setState keeps this in sync.
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            // Selected: solid primary fill (same as active FeatureGrid tile
            // icon container). Hovered-unselected: primaryLight 15% tint.
            color: widget.isSelected
                ? AppColors.primary
                : _hovered
                    ? AppColors.primaryLight.withValues(alpha: 0.15)
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
