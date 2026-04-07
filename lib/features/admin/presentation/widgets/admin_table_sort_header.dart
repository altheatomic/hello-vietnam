import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';

// ── Shared sort enums ─────────────────────────────────────────────────────────

/// The three choices in every admin column sort menu.
enum SortMenuAction { defaultOrder, ascending, descending }

/// Active sort direction once a non-default order is chosen.
enum SortDirection { ascending, descending }

// ── Widget ────────────────────────────────────────────────────────────────────

/// Reusable column-header sort button for admin tables.
///
/// [T] is the page-specific sort-field enum. Each page defines its own private
/// enum and passes it here — this widget stays generic and works for all of
/// them via Dart's built-in [Enum] equality.
///
/// Usage:
/// ```dart
/// AdminTableSortHeader<_MySortField>(
///   label: 'Full Name',
///   field: _MySortField.name,
///   activeSortField: _activeSortField,
///   activeSortDirection: _activeSortDirection,
///   onSelected: _onSortSelected,
/// )
/// ```
class AdminTableSortHeader<T extends Enum> extends StatelessWidget {
  const AdminTableSortHeader({
    super.key,
    required this.label,
    required this.field,
    required this.activeSortField,
    required this.activeSortDirection,
    required this.onSelected,
  });

  final String label;
  final T field;
  final T? activeSortField;
  final SortDirection? activeSortDirection;

  /// Called with the field that was clicked and the user's chosen action.
  final void Function(T field, SortMenuAction action) onSelected;

  bool get _isActive =>
      activeSortField == field && activeSortDirection != null;

  IconData get _icon {
    if (!_isActive) return Icons.unfold_more_rounded;
    return activeSortDirection == SortDirection.ascending
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelMedium;
    final menuTheme = Theme.of(context).copyWith(
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.divider),
        ),
        textStyle: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textPrimary),
      ),
    );

    return Row(
      children: [
        Expanded(
          child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis),
        ),
        Theme(
          data: menuTheme,
          child: PopupMenuButton<SortMenuAction>(
            tooltip: 'Sort $label',
            requestFocus: false,
            offset: const Offset(0, 12),
            onSelected: (action) => onSelected(field, action),
            itemBuilder: (context) => [
              _AdminSortMenuItem(
                value: SortMenuAction.defaultOrder,
                label: 'Default',
                selected: !_isActive,
                icon: Icons.history_rounded,
              ),
              _AdminSortMenuItem(
                value: SortMenuAction.ascending,
                label: 'A → Z',
                selected:
                    _isActive &&
                    activeSortDirection == SortDirection.ascending,
                icon: Icons.arrow_upward_rounded,
              ),
              _AdminSortMenuItem(
                value: SortMenuAction.descending,
                label: 'Z → A',
                selected:
                    _isActive &&
                    activeSortDirection == SortDirection.descending,
                icon: Icons.arrow_downward_rounded,
              ),
            ],
            padding: EdgeInsets.zero,
            splashRadius: 18,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: AnimatedContainer(
              duration: AppConstants.defaultAnimation,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _isActive
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isActive
                      ? AppColors.primary.withValues(alpha: 0.30)
                      : AppColors.divider,
                ),
                boxShadow: _isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                _icon,
                size: 15,
                color: _isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Menu item ─────────────────────────────────────────────────────────────────

class _AdminSortMenuItem extends PopupMenuItem<SortMenuAction> {
  _AdminSortMenuItem({
    required super.value,
    required String label,
    required bool selected,
    required IconData icon,
  }) : super(
         height: 44,
         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
         child: Container(
           decoration: BoxDecoration(
             color: selected
                 ? AppColors.primary.withValues(alpha: 0.10)
                 : Colors.transparent,
             borderRadius: BorderRadius.circular(10),
           ),
           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
           child: Row(
             children: [
               Icon(
                 icon,
                 size: 16,
                 color: selected ? AppColors.primary : AppColors.textSecondary,
               ),
               const SizedBox(width: 10),
               Expanded(
                 child: Text(
                   label,
                   style: TextStyle(
                     fontSize: 13,
                     fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                     color:
                         selected ? AppColors.primaryDark : AppColors.textPrimary,
                   ),
                 ),
               ),
               AnimatedOpacity(
                 duration: AppConstants.defaultAnimation,
                 opacity: selected ? 1 : 0,
                 child: const Icon(
                   Icons.check_rounded,
                   size: 16,
                   color: AppColors.primary,
                 ),
               ),
             ],
           ),
         ),
       );
}
