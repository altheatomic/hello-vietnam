import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import '../../data/admin_food_mock_data.dart';
import '../../domain/admin_food.dart';
import '../widgets/admin_section_header.dart';
import '../widgets/food_form_dialog.dart';
import '../widgets/food_type_manager_dialog.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class AdminFoodPage extends StatefulWidget {
  const AdminFoodPage({super.key});

  @override
  State<AdminFoodPage> createState() => _AdminFoodPageState();
}

enum _FoodSortField { name, city }

enum _FoodSortDirection { ascending, descending }

enum _FoodSortMenuAction { defaultOrder, ascending, descending }

class _AdminFoodPageState extends State<AdminFoodPage> {
  late final List<AdminFood> _foods = mockAdminFoods.map((f) => f).toList();

  late final List<FoodType> _types = defaultFoodTypes.map((t) => t).toList();

  final TextEditingController _searchController = TextEditingController();
  String? _filterTypeId;
  _FoodSortField? _activeSortField;
  _FoodSortDirection? _activeSortDirection;
  int _currentPage = 1;
  static const int _pageSize = 8;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  FoodType _resolveType(String typeId) => _types.firstWhere(
    (t) => t.id == typeId,
    orElse: () => FoodType(id: typeId, label: typeId, colorIndex: 4),
  );

  Map<String, int> get _foodCounts {
    final counts = <String, int>{};
    for (final f in _foods) {
      counts[f.typeId] = (counts[f.typeId] ?? 0) + 1;
    }
    return counts;
  }

  int _compareFoodId(String a, String b) {
    final partsA = RegExp(
      r'\d+|\D+',
    ).allMatches(a).map((m) => m.group(0)!).toList();
    final partsB = RegExp(
      r'\d+|\D+',
    ).allMatches(b).map((m) => m.group(0)!).toList();
    final length = min(partsA.length, partsB.length);

    for (var i = 0; i < length; i++) {
      final segmentA = partsA[i];
      final segmentB = partsB[i];
      final numberA = int.tryParse(segmentA);
      final numberB = int.tryParse(segmentB);

      final result = (numberA != null && numberB != null)
          ? numberA.compareTo(numberB)
          : segmentA.toLowerCase().compareTo(segmentB.toLowerCase());

      if (result != 0) return result;
    }

    return partsA.length.compareTo(partsB.length);
  }

  // ── Filtering & pagination ─────────────────────────────────────────────────

  List<AdminFood> get _filtered {
    final q = _searchController.text.toLowerCase().trim();
    // Base order is always id ASC — this is the default and reset state.
    final filtered = _foods.where((f) {
      final matchSearch =
          q.isEmpty ||
          f.name.toLowerCase().contains(q) ||
          f.city.toLowerCase().contains(q);
      final matchType = _filterTypeId == null || f.typeId == _filterTypeId;
      return matchSearch && matchType;
    }).toList()..sort((a, b) => _compareFoodId(a.id, b.id));

    // When no sort is active (initial load or after reset), return id ASC.
    if (_activeSortField == null || _activeSortDirection == null) {
      return filtered;
    }

    int compareText(String left, String right) =>
        left.toLowerCase().compareTo(right.toLowerCase());

    filtered.sort((a, b) {
      final result = switch (_activeSortField!) {
        _FoodSortField.name => compareText(a.name, b.name),
        _FoodSortField.city => compareText(a.city, b.city),
      };

      if (result != 0) {
        return _activeSortDirection == _FoodSortDirection.ascending
            ? result
            : -result;
      }

      return _compareFoodId(a.id, b.id);
    });

    return filtered;
  }

  List<AdminFood> get _paged {
    final all = _filtered;
    final start = (_currentPage - 1) * _pageSize;
    final end = min(start + _pageSize, all.length);
    if (start >= all.length) return [];
    return all.sublist(start, end);
  }

  int get _totalPages =>
      (_filtered.length / _pageSize).ceil().clamp(1, double.maxFinite).toInt();

  void _onSearchChanged(String _) => setState(() => _currentPage = 1);

  void _onTypeFilterChanged(String? id) => setState(() {
    _filterTypeId = id;
    _currentPage = 1;
  });

  void _onSortSelected(_FoodSortField field, _FoodSortMenuAction action) =>
      setState(() {
        if (action == _FoodSortMenuAction.defaultOrder) {
          _activeSortField = null;
          _activeSortDirection = null;
        } else {
          _activeSortField = field;
          _activeSortDirection = action == _FoodSortMenuAction.ascending
              ? _FoodSortDirection.ascending
              : _FoodSortDirection.descending;
        }
        _currentPage = 1;
      });

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> _openCreate() async {
    final result = await showDialog<AdminFood>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FoodFormDialog(types: _types),
    );
    if (result == null) return;
    setState(() => _foods.insert(0, result));
    _showSnack('"${result.name}" added.');
  }

  Future<void> _openEdit(AdminFood food) async {
    final result = await showDialog<AdminFood>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FoodFormDialog(initial: food, types: _types),
    );
    if (result == null) return;
    setState(() {
      final idx = _foods.indexWhere((f) => f.id == result.id);
      if (idx != -1) _foods[idx] = result;
    });
    _showSnack('"${result.name}" updated.');
  }

  Future<void> _openView(AdminFood food) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _FoodViewDialog(food: food, type: _resolveType(food.typeId)),
    );
  }

  Future<void> _confirmDelete(AdminFood food) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirmDialog(name: food.name),
    );
    if (ok != true) return;
    setState(() => _foods.removeWhere((f) => f.id == food.id));
    _showSnack('"${food.name}" deleted.');
  }

  // ── Manage Types ───────────────────────────────────────────────────────────

  Future<void> _openManageTypes() async {
    final result = await showDialog<List<FoodType>>(
      context: context,
      builder: (_) => FoodTypeManagerDialog(
        initialTypes: _types,
        foodCountForType: _foodCounts,
      ),
    );
    if (result == null) return;

    setState(() {
      final oldIds = _types.map((t) => t.id).toSet();
      final newIds = result.map((t) => t.id).toSet();
      final deletedIds = oldIds.difference(newIds);

      if (deletedIds.isNotEmpty) {
        final fallbackId = result.isNotEmpty ? result.first.id : 'other';
        for (int i = 0; i < _foods.length; i++) {
          if (deletedIds.contains(_foods[i].typeId)) {
            _foods[i] = _foods[i].copyWith(typeId: fallbackId);
          }
        }
        if (_filterTypeId != null && deletedIds.contains(_filterTypeId)) {
          _filterTypeId = null;
        }
      }

      _types
        ..clear()
        ..addAll(result);
    });

    _showSnack('Types updated.');
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final paged = _paged;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              AdminSectionHeader(
                title: 'Food Management',
                subtitle: 'Create and manage Vietnamese food entries',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openManageTypes,
                      icon: const Icon(
                        Icons.restaurant_menu_outlined,
                        size: 16,
                      ),
                      label: const Text('Manage Types'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.divider, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.buttonRadius,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _openCreate,
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text('Add Food'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.buttonRadius,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _FoodContentCard(
                filterBar: _TypeFilterBar(
                  controller: _searchController,
                  types: _types,
                  selectedId: _filterTypeId,
                  onTypeChanged: _onTypeFilterChanged,
                  onSearchChanged: _onSearchChanged,
                ),
                child: filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: EmptyState(
                          icon: Icons.restaurant_outlined,
                          message: 'No food items match your search.',
                        ),
                      )
                    : Column(
                        children: [
                          _FoodTable(
                            foods: paged,
                            resolveType: _resolveType,
                            activeSortField: _activeSortField,
                            activeSortDirection: _activeSortDirection,
                            onSortSelected: _onSortSelected,
                            onView: _openView,
                            onEdit: _openEdit,
                            onDelete: _confirmDelete,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            child: _TableFooter(
                              currentPage: _currentPage,
                              totalPages: _totalPages,
                              totalItems: filtered.length,
                              pageSize: _pageSize,
                              onPageChanged: (p) =>
                                  setState(() => _currentPage = p),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search + type filter bar ──────────────────────────────────────────────────

class _TypeFilterBar extends StatelessWidget {
  const _TypeFilterBar({
    required this.controller,
    required this.types,
    required this.selectedId,
    required this.onTypeChanged,
    required this.onSearchChanged,
  });

  final TextEditingController controller;
  final List<FoodType> types;
  final String? selectedId;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search pill
        Container(
          width: 300,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(45),
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
            onChanged: onSearchChanged,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by name or city…',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 19,
                color: AppColors.textSecondary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
            ),
          ),
        ),

        const Spacer(),

        // "All" chip
        _FoodFilterChip(
          label: 'All',
          isSelected: selectedId == null,
          onTap: () => onTypeChanged(null),
        ),
        const SizedBox(width: 6),

        ...types.map(
          (t) => Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _FoodFilterChip(
              label: t.label,
              isSelected: selectedId == t.id,
              color: t.color,
              onTap: () => onTypeChanged(selectedId == t.id ? null : t.id),
            ),
          ),
        ),
      ],
    );
  }
}

class _FoodContentCard extends StatelessWidget {
  const _FoodContentCard({required this.filterBar, required this.child});

  final Widget filterBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: filterBar,
          ),
          Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.9)),
          child,
        ],
      ),
    );
  }
}

class _FoodFilterChip extends StatelessWidget {
  const _FoodFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.defaultAnimation,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.surface,
          borderRadius: BorderRadius.circular(45),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.divider,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _FoodTable extends StatelessWidget {
  const _FoodTable({
    required this.foods,
    required this.resolveType,
    required this.activeSortField,
    required this.activeSortDirection,
    required this.onSortSelected,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AdminFood> foods;
  final FoodType Function(String) resolveType;
  final _FoodSortField? activeSortField;
  final _FoodSortDirection? activeSortDirection;
  final void Function(_FoodSortField field, _FoodSortMenuAction action)
  onSortSelected;
  final ValueChanged<AdminFood> onView, onEdit, onDelete;

  static const double _colId = 110;
  static const double _colName = 180;
  static const double _colType = 108;
  static const double _colCity = 156;
  static const double _colImg = 56;
  static const double _colActions = 112;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider.withValues(alpha: 0.9)),
          bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.9)),
        ),
      ),
      child: ClipRRect(
        child: Column(
          children: [
            _FoodTableHeader(
              colId: _colId,
              colName: _colName,
              colType: _colType,
              colCity: _colCity,
              colImg: _colImg,
              colActions: _colActions,
              activeSortField: activeSortField,
              activeSortDirection: activeSortDirection,
              onSortSelected: onSortSelected,
            ),
            ...List.generate(
              foods.length,
              (i) => _FoodRow(
                food: foods[i],
                type: resolveType(foods[i].typeId),
                isLast: i == foods.length - 1,
                colId: _colId,
                onView: () => onView(foods[i]),
                onEdit: () => onEdit(foods[i]),
                onDelete: () => onDelete(foods[i]),
                colName: _colName,
                colType: _colType,
                colCity: _colCity,
                colImg: _colImg,
                colActions: _colActions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Table header ──────────────────────────────────────────────────────────────

class _FoodTableHeader extends StatelessWidget {
  const _FoodTableHeader({
    required this.colId,
    required this.colName,
    required this.colType,
    required this.colCity,
    required this.colImg,
    required this.colActions,
    required this.activeSortField,
    required this.activeSortDirection,
    required this.onSortSelected,
  });

  final double colId,
      colName,
      colType,
      colCity,
      colImg,
      colActions;
  final _FoodSortField? activeSortField;
  final _FoodSortDirection? activeSortDirection;
  final void Function(_FoodSortField field, _FoodSortMenuAction action)
  onSortSelected;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    return Container(
      height: 46,
      color: AppColors.primaryLight.withValues(alpha: 0.13),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _FoodCell(
            width: colId,
            child: Text('Food ID', style: style),
          ),
          _FoodCell(
            width: colName,
            child: _FoodSortHeader(
              label: 'Name',
              field: _FoodSortField.name,
              activeSortField: activeSortField,
              activeSortDirection: activeSortField == _FoodSortField.name
                  ? activeSortDirection
                  : null,
              onSortSelected: onSortSelected,
            ),
          ),
          const _FoodExpandedCell(
            child: Text(
              'Description',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          _FoodCell(
            width: colType,
            child: Text('Type', style: style),
          ),
          _FoodCell(
            width: colCity,
            child: _FoodSortHeader(
              label: 'City / Province',
              field: _FoodSortField.city,
              activeSortField: activeSortField,
              activeSortDirection: activeSortField == _FoodSortField.city
                  ? activeSortDirection
                  : null,
              onSortSelected: onSortSelected,
            ),
          ),
          _FoodCell(
            width: colImg,
            child: Text('Image', style: style),
          ),
          _FoodCell(
            width: colActions,
            child: Text('Actions', style: style),
          ),
        ],
      ),
    );
  }
}

// ── Data row ──────────────────────────────────────────────────────────────────

class _FoodRow extends StatefulWidget {
  const _FoodRow({
    required this.food,
    required this.type,
    required this.isLast,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.colId,
    required this.colName,
    required this.colType,
    required this.colCity,
    required this.colImg,
    required this.colActions,
  });

  final AdminFood food;
  final FoodType type;
  final bool isLast;
  final VoidCallback onView, onEdit, onDelete;
  final double colId,
      colName,
      colType,
      colCity,
      colImg,
      colActions;

  @override
  State<_FoodRow> createState() => _FoodRowState();
}

class _FoodRowState extends State<_FoodRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.food;
    final t = widget.type;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.defaultAnimation,
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.primaryLight.withValues(alpha: 0.06)
              : AppColors.surface,
          border: widget.isLast
              ? null
              : Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            _FoodCell(
              width: widget.colId,
              child: Text(
                f.id,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Name
            _FoodCell(
              width: widget.colName,
              child: Text(
                f.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Description preview
            _FoodExpandedCell(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                f.description ?? '—',
                style: bodyStyle?.copyWith(color: AppColors.textSecondary),
                maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Type badge
            _FoodCell(
              width: widget.colType,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TypeBadge(type: t),
              ),
            ),

            // City
            _FoodCell(
              width: widget.colCity,
              child: Text(
                f.city,
                style: bodyStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Image indicator
            _FoodCell(
              width: widget.colImg,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message: f.hasImage ? 'Has image' : 'No image',
                  child: Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: f.hasImage
                        ? AppColors.primary
                        : AppColors.textSecondary.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),

            // Actions
            _FoodCell(
              width: widget.colActions,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  _FoodIconAction(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View',
                    color: AppColors.primary,
                    onTap: widget.onView,
                  ),
                  const SizedBox(width: 4),
                  _FoodIconAction(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    color: AppColors.primaryDark,
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 4),
                  _FoodIconAction(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete',
                    color: const Color(0xFFEF4444),
                    onTap: widget.onDelete,
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

// ── Layout helpers ────────────────────────────────────────────────────────────

class _FoodCell extends StatelessWidget {
  const _FoodCell({required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

/// Fills remaining horizontal space — used for the Description column so the
/// table stretches edge-to-edge and left/right padding stays balanced.
class _FoodExpandedCell extends StatelessWidget {
  const _FoodExpandedCell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Expanded(child: child);
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _FoodSortHeader extends StatelessWidget {
  const _FoodSortHeader({
    required this.label,
    required this.field,
    required this.activeSortField,
    required this.activeSortDirection,
    required this.onSortSelected,
  });

  final String label;
  final _FoodSortField field;
  final _FoodSortField? activeSortField;
  final _FoodSortDirection? activeSortDirection;
  final void Function(_FoodSortField field, _FoodSortMenuAction action)
  onSortSelected;

  bool get _isActive => activeSortField == field && activeSortDirection != null;

  IconData get _icon {
    if (!_isActive) return Icons.unfold_more_rounded;
    return activeSortDirection == _FoodSortDirection.ascending
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
  }

  Future<void> _openSortMenu(BuildContext context, ThemeData menuTheme) async {
    final button = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final buttonRect = Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );

    final action = await showMenu<_FoodSortMenuAction>(
      context: context,
      position: RelativeRect.fromRect(buttonRect, Offset.zero & overlay.size),
      elevation: menuTheme.popupMenuTheme.elevation,
      color: menuTheme.popupMenuTheme.color,
      shadowColor: menuTheme.popupMenuTheme.shadowColor,
      shape: menuTheme.popupMenuTheme.shape,
      items: [
        _FoodSortMenuItem(
          value: _FoodSortMenuAction.defaultOrder,
          label: 'Default',
          selected: !_isActive,
          icon: Icons.history_rounded,
        ),
        _FoodSortMenuItem(
          value: _FoodSortMenuAction.ascending,
          label: 'A -> Z',
          selected:
              _isActive &&
              activeSortDirection == _FoodSortDirection.ascending,
          icon: Icons.arrow_upward_rounded,
        ),
        _FoodSortMenuItem(
          value: _FoodSortMenuAction.descending,
          label: 'Z -> A',
          selected:
              _isActive &&
              activeSortDirection == _FoodSortDirection.descending,
          icon: Icons.arrow_downward_rounded,
        ),
      ],
    );

    if (action != null && context.mounted) {
      onSortSelected(field, action);
    }
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
        textStyle: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
      ),
    );

    return Row(
      children: [
        Expanded(
          child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis),
        ),
        Theme(
          data: menuTheme,
          child: PopupMenuButton<_FoodSortMenuAction>(
            tooltip: 'Sort $label',
            requestFocus: false,
            offset: const Offset(0, 12),
            onSelected: (action) => onSortSelected(field, action),
            itemBuilder: (context) => [
              _FoodSortMenuItem(
                value: _FoodSortMenuAction.defaultOrder,
                label: 'Default',
                selected: !_isActive,
                icon: Icons.history_rounded,
              ),
              _FoodSortMenuItem(
                value: _FoodSortMenuAction.ascending,
                label: 'A → Z',
                selected:
                    _isActive &&
                    activeSortDirection == _FoodSortDirection.ascending,
                icon: Icons.arrow_upward_rounded,
              ),
              _FoodSortMenuItem(
                value: _FoodSortMenuAction.descending,
                label: 'Z → A',
                selected:
                    _isActive &&
                    activeSortDirection == _FoodSortDirection.descending,
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

class _FoodSortMenuItem extends PopupMenuItem<_FoodSortMenuAction> {
  _FoodSortMenuItem({
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
                     color: selected
                         ? AppColors.primaryDark
                         : AppColors.textPrimary,
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

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final FoodType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: type.color,
        ),
      ),
    );
  }
}

class _FoodIconAction extends StatefulWidget {
  const _FoodIconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_FoodIconAction> createState() => _FoodIconActionState();
}

class _FoodIconActionState extends State<_FoodIconAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppConstants.defaultAnimation,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 17, color: widget.color),
          ),
        ),
      ),
    );
  }
}

// ── Pagination footer ─────────────────────────────────────────────────────────

class _TableFooter extends StatelessWidget {
  const _TableFooter({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
  });

  final int currentPage, totalPages, totalItems, pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final start = (currentPage - 1) * pageSize + 1;
    final end = min(currentPage * pageSize, totalItems);

    return Row(
      children: [
        Text(
          'Showing $start–$end of $totalItems items',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const Spacer(),
        _PgBtn(
          icon: Icons.chevron_left_rounded,
          enabled: currentPage > 1,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        const SizedBox(width: 4),
        ...List.generate(totalPages, (i) {
          final page = i + 1;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _PgBtn(
              label: '$page',
              isActive: page == currentPage,
              onTap: () => onPageChanged(page),
            ),
          );
        }),
        _PgBtn(
          icon: Icons.chevron_right_rounded,
          enabled: currentPage < totalPages,
          onTap: () => onPageChanged(currentPage + 1),
        ),
      ],
    );
  }
}

class _PgBtn extends StatelessWidget {
  const _PgBtn({
    this.label,
    this.icon,
    this.isActive = false,
    this.enabled = true,
    required this.onTap,
  });
  final String? label;
  final IconData? icon;
  final bool isActive, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: AppConstants.defaultAnimation,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  size: 18,
                  color: enabled
                      ? AppColors.textSecondary
                      : AppColors.textSecondary.withValues(alpha: 0.3),
                )
              : Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isActive ? Colors.white : AppColors.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── View dialog ───────────────────────────────────────────────────────────────

class _FoodViewDialog extends StatelessWidget {
  const _FoodViewDialog({required this.food, required this.type});
  final AdminFood food;
  final FoodType type;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        _TypeBadge(type: type),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              _VRow(label: 'ID', value: food.id),
              _VRow(label: 'City', value: food.city),
              _VRow(label: 'Image URL', value: food.urlImage ?? '—'),
              _VRow(label: 'Description', value: food.description ?? '—'),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.buttonRadius,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VRow extends StatelessWidget {
  const _VRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ── Delete confirmation ───────────────────────────────────────────────────────

class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      title: const Text('Delete Food'),
      content: Text(
        'Are you sure you want to delete "$name"?\nThis action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
