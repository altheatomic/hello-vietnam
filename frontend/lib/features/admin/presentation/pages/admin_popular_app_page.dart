import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import '../../data/admin_popular_app_repository.dart';
import '../../domain/popular_app_guide.dart';
import '../widgets/admin_section_header.dart';
import '../widgets/admin_table_sort_header.dart';
import '../widgets/category_manager_dialog.dart';
import '../widgets/popular_app_form_dialog.dart';

enum _AppSortField { name }

// ── Page ─────────────────────────────────────────────────────────────────────

class AdminPopularAppPage extends StatefulWidget {
  const AdminPopularAppPage({super.key});

  @override
  State<AdminPopularAppPage> createState() => _AdminPopularAppPageState();
}

class _AdminPopularAppPageState extends State<AdminPopularAppPage> {
  final AdminPopularAppRepository _repo = AdminPopularAppRepository();

  List<PopularAppGuide> _guides = [];
  List<AppCategory> _categories = [];
  bool _loading = true;

  final TextEditingController _searchController = TextEditingController();

  String? _filterCategoryId;
  _AppSortField? _activeSortField;
  SortDirection? _activeSortDirection;
  int _currentPage = 1;
  static const int _pageSize = 8;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.fetchApps(),
        _repo.fetchCategories(),
      ]);
      setState(() {
        _guides = results[0] as List<PopularAppGuide>;
        _categories = results[1] as List<AppCategory>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('Failed to load data: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Resolves a category by ID; returns an "Unknown" placeholder if not found.
  AppCategory _resolveCategory(String categoryId) => _categories.firstWhere(
    (c) => c.id == categoryId,
    orElse: () => AppCategory(id: categoryId, label: categoryId, colorIndex: 4),
  );

  /// Maps categoryId → guide count (used by the delete confirmation).
  Map<String, int> get _guideCounts {
    final counts = <String, int>{};
    for (final g in _guides) {
      counts[g.categoryId] = (counts[g.categoryId] ?? 0) + 1;
    }
    return counts;
  }

  // ── Filtering & pagination ─────────────────────────────────────────────────

  /// Base order: id ASC. Active sort applied on top with id as tiebreaker.
  List<PopularAppGuide> get _filtered {
    final q = _searchController.text.toLowerCase().trim();
    final result = _guides.where((g) {
      final matchesSearch = q.isEmpty || g.name.toLowerCase().contains(q);
      final matchesCat =
          _filterCategoryId == null || g.categoryId == _filterCategoryId;
      return matchesSearch && matchesCat;
    }).toList()..sort((a, b) => a.id.compareTo(b.id));

    if (_activeSortField == null || _activeSortDirection == null) return result;

    result.sort((a, b) {
      final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (cmp != 0) {
        return _activeSortDirection == SortDirection.ascending ? cmp : -cmp;
      }
      return a.id.compareTo(b.id);
    });
    return result;
  }

  List<PopularAppGuide> get _paged {
    final all = _filtered;
    final start = (_currentPage - 1) * _pageSize;
    final end = min(start + _pageSize, all.length);
    if (start >= all.length) return [];
    return all.sublist(start, end);
  }

  int get _totalPages =>
      (_filtered.length / _pageSize).ceil().clamp(1, double.maxFinite).toInt();

  void _onSearchChanged(String _) => setState(() => _currentPage = 1);

  void _onCategoryFilterChanged(String? id) => setState(() {
    _filterCategoryId = id;
    _currentPage = 1;
  });

  void _onSortSelected(_AppSortField field, SortMenuAction action) =>
      setState(() {
        if (action == SortMenuAction.defaultOrder) {
          _activeSortField = null;
          _activeSortDirection = null;
        } else {
          _activeSortField = field;
          _activeSortDirection = action == SortMenuAction.ascending
              ? SortDirection.ascending
              : SortDirection.descending;
        }
        _currentPage = 1;
      });

  // ── Guide CRUD ─────────────────────────────────────────────────────────────

  Future<void> _openCreate() async {
    final result = await showDialog<PopularAppGuide>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopularAppFormDialog(categories: _categories),
    );
    if (result == null) return;
    try {
      final created = await _repo.createApp(app: result);
      setState(() => _guides.insert(0, created));
      _showSnack('Guide "${created.name}" added.');
    } catch (e) {
      _showSnack('Failed to create guide: $e');
    }
  }

  Future<void> _openEdit(PopularAppGuide guide) async {
    final result = await showDialog<PopularAppGuide>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          PopularAppFormDialog(initial: guide, categories: _categories),
    );
    if (result == null) return;
    try {
      final updated = await _repo.updateApp(app: result);
      setState(() {
        final idx = _guides.indexWhere((g) => g.id == updated.id);
        if (idx != -1) _guides[idx] = updated;
      });
      _showSnack('Guide "${updated.name}" updated.');
    } catch (e) {
      _showSnack('Failed to update guide: $e');
    }
  }

  Future<void> _openView(PopularAppGuide guide) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ViewDialog(
        guide: guide,
        category: _resolveCategory(guide.categoryId),
      ),
    );
  }

  Future<void> _confirmDelete(PopularAppGuide guide) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirmDialog(name: guide.name),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteApp(guide.id);
      setState(() => _guides.removeWhere((g) => g.id == guide.id));
      _showSnack('Guide "${guide.name}" deleted.');
    } catch (e) {
      _showSnack('Failed to delete guide: $e');
    }
  }

  // ── Category management ────────────────────────────────────────────────────

  Future<void> _openManageCategories() async {
    final result = await showDialog<List<AppCategory>>(
      context: context,
      builder: (_) => CategoryManagerDialog(
        initialCategories: _categories,
        guideCountForCategory: _guideCounts,
      ),
    );

    // null = user pressed ×; non-null = user pressed Done
    if (result == null) return;

    try {
      final oldIds = _categories.map((c) => c.id).toSet();
      final newIds = result.map((c) => c.id).toSet();
      final deletedIds = oldIds.difference(newIds);
      final fallbackId = result.isNotEmpty ? result.first.id : 'other';

      for (final id in deletedIds) {
        await _repo.reassignCategory(fromId: id, toId: fallbackId);
        await _repo.deleteCategory(id);
      }
      for (final cat in result) {
        await _repo.upsertCategory(category: cat);
      }

      setState(() {
        if (deletedIds.isNotEmpty) {
          for (int i = 0; i < _guides.length; i++) {
            if (deletedIds.contains(_guides[i].categoryId)) {
              _guides[i] = _guides[i].copyWith(categoryId: fallbackId);
            }
          }
          if (_filterCategoryId != null &&
              deletedIds.contains(_filterCategoryId)) {
            _filterCategoryId = null;
          }
        }
        _categories
          ..clear()
          ..addAll(result);
      });

      _showSnack('Categories updated.');
    } catch (e) {
      _showSnack('Failed to update categories: $e');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;
    final paged = _paged;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          AdminSectionHeader(
            title: 'Popular App Guides',
            subtitle:
                'Create and manage in-app guides for popular Vietnam apps',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Manage Categories — outlined secondary action
                OutlinedButton.icon(
                  onPressed: _openManageCategories,
                  icon: const Icon(Icons.category_outlined, size: 16),
                  label: const Text('Manage Categories'),
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
                // Add Guide — primary filled action
                FilledButton.icon(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Add Guide'),
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

          // ── Search + category filter ─────────────────────────────────────────
          _CategoryFilterBar(
            controller: _searchController,
            categories: _categories,
            selectedId: _filterCategoryId,
            onCategoryChanged: _onCategoryFilterChanged,
            onSearchChanged: _onSearchChanged,
          ),

          const SizedBox(height: 16),

          // ── Table or empty state ─────────────────────────────────────────────
          if (filtered.isEmpty)
            EmptyState(
              icon: Icons.apps_outlined,
              message:
                  'No guides match your search.\nTry a different name or category.',
            )
          else ...[
            _GuideTable(
              guides: paged,
              resolveCategory: _resolveCategory,
              onView: _openView,
              onEdit: _openEdit,
              onDelete: _confirmDelete,
              activeSortField: _activeSortField,
              activeSortDirection: _activeSortDirection,
              onSortSelected: _onSortSelected,
            ),

            const SizedBox(height: 16),

            _TableFooter(
              currentPage: _currentPage,
              totalPages: _totalPages,
              totalItems: filtered.length,
              pageSize: _pageSize,
              onPageChanged: (p) => setState(() => _currentPage = p),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Search + filter bar ───────────────────────────────────────────────────────

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.controller,
    required this.categories,
    required this.selectedId,
    required this.onCategoryChanged,
    required this.onSearchChanged,
  });

  final TextEditingController controller;
  final List<AppCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onCategoryChanged;
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
              hintText: 'Search by app name…',
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
        _FilterChip(
          label: 'All',
          isSelected: selectedId == null,
          onTap: () => onCategoryChanged(null),
        ),
        const SizedBox(width: 6),

        // One chip per category — driven by the runtime list
        ...categories.map(
          (cat) => Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _FilterChip(
              label: cat.label,
              isSelected: selectedId == cat.id,
              color: cat.color,
              onTap: () =>
                  onCategoryChanged(selectedId == cat.id ? null : cat.id),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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

class _GuideTable extends StatelessWidget {
  const _GuideTable({
    required this.guides,
    required this.resolveCategory,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.activeSortField,
    required this.activeSortDirection,
    required this.onSortSelected,
  });

  final List<PopularAppGuide> guides;
  final AppCategory Function(String) resolveCategory;
  final ValueChanged<PopularAppGuide> onView, onEdit, onDelete;
  final _AppSortField? activeSortField;
  final SortDirection? activeSortDirection;
  final void Function(_AppSortField, SortMenuAction) onSortSelected;

  static const double _colName = 200;
  static const double _colCat = 116;
  static const double _colMedia = 80;
  static const double _colPkg = 200;
  static const double _colActions = 108;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        child: Column(
          children: [
            _TableHeader(
              colName: _colName,
              colCat: _colCat,
              colMedia: _colMedia,
              colPkg: _colPkg,
              colActions: _colActions,
              activeSortField: activeSortField,
              activeSortDirection: activeSortDirection,
              onSortSelected: onSortSelected,
            ),
            ...List.generate(
              guides.length,
              (i) => _GuideRow(
                guide: guides[i],
                category: resolveCategory(guides[i].categoryId),
                isLast: i == guides.length - 1,
                onView: () => onView(guides[i]),
                onEdit: () => onEdit(guides[i]),
                onDelete: () => onDelete(guides[i]),
                colName: _colName,
                colCat: _colCat,
                colMedia: _colMedia,
                colPkg: _colPkg,
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

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.colName,
    required this.colCat,
    required this.colMedia,
    required this.colPkg,
    required this.colActions,
    required this.activeSortField,
    required this.activeSortDirection,
    required this.onSortSelected,
  });

  final double colName, colCat, colMedia, colPkg, colActions;
  final _AppSortField? activeSortField;
  final SortDirection? activeSortDirection;
  final void Function(_AppSortField, SortMenuAction) onSortSelected;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    return Container(
      height: 46,
      color: AppColors.primaryLight.withValues(alpha: 0.13),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _Cell(
            width: colName,
            child: AdminTableSortHeader<_AppSortField>(
              label: 'App Name',
              field: _AppSortField.name,
              activeSortField: activeSortField,
              activeSortDirection: activeSortDirection,
              onSelected: onSortSelected,
            ),
          ),
          const _ExpandedCell(
            child: Text(
              'Description',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          _Cell(
            width: colCat,
            child: Text('Category', style: style),
          ),
          _Cell(
            width: colMedia,
            child: Text('Media', style: style),
          ),
          _Cell(
            width: colPkg,
            child: Text('Package', style: style),
          ),
          _Cell(
            width: colActions,
            child: Text('Actions', style: style),
          ),
        ],
      ),
    );
  }
}

// ── Data row ──────────────────────────────────────────────────────────────────

class _GuideRow extends StatefulWidget {
  const _GuideRow({
    required this.guide,
    required this.category,
    required this.isLast,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.colName,
    required this.colCat,
    required this.colMedia,
    required this.colPkg,
    required this.colActions,
  });

  final PopularAppGuide guide;
  final AppCategory category;
  final bool isLast;
  final VoidCallback onView, onEdit, onDelete;
  final double colName, colCat, colMedia, colPkg, colActions;

  @override
  State<_GuideRow> createState() => _GuideRowState();
}

class _GuideRowState extends State<_GuideRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    final cat = widget.category;
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
            // App name
            _Cell(
              width: widget.colName,
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      g.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Description preview
            Expanded(
              child: Text(
                g.description ?? '—',
                style: bodyStyle?.copyWith(color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Category badge — label + color from resolved AppCategory
            _Cell(
              width: widget.colCat,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _CategoryBadge(category: cat),
              ),
            ),

            // Media indicators
            _Cell(
              width: widget.colMedia,
              child: Row(
                children: [
                  _MediaDot(
                    icon: Icons.image_outlined,
                    active: g.hasImage,
                    tooltip: g.hasImage ? 'Has image' : 'No image',
                  ),
                  const SizedBox(width: 6),
                  _MediaDot(
                    icon: Icons.play_circle_outline_rounded,
                    active: g.hasVideo,
                    tooltip: g.hasVideo ? 'Has video' : 'No video',
                  ),
                ],
              ),
            ),

            // Package name
            _Cell(
              width: widget.colPkg,
              child: Text(
                g.packageName,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Actions
            _Cell(
              width: widget.colActions,
              child: Row(
                children: [
                  _IconAction(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View',
                    color: AppColors.primary,
                    onTap: widget.onView,
                  ),
                  const SizedBox(width: 4),
                  _IconAction(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    color: AppColors.primaryDark,
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 4),
                  _IconAction(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete',
                    color: const Color(0xFFEF4444),
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Layout helpers ─────────────────────────────────────────────────────────────

class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.child});
  final double width;
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

class _ExpandedCell extends StatelessWidget {
  const _ExpandedCell({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Expanded(child: child);
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});
  final AppCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: category.color,
        ),
      ),
    );
  }
}

class _MediaDot extends StatelessWidget {
  const _MediaDot({
    required this.icon,
    required this.active,
    required this.tooltip,
  });
  final IconData icon;
  final bool active;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        size: 18,
        color: active
            ? AppColors.primary
            : AppColors.textSecondary.withValues(alpha: 0.35),
      ),
    );
  }
}

class _IconAction extends StatefulWidget {
  const _IconAction({
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
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
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

// ── Footer / pagination ───────────────────────────────────────────────────────

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
          'Showing $start–$end of $totalItems guides',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const Spacer(),
        _PageButton(
          icon: Icons.chevron_left_rounded,
          enabled: currentPage > 1,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        const SizedBox(width: 4),
        ...List.generate(totalPages, (i) {
          final page = i + 1;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _PageButton(
              label: '$page',
              isActive: page == currentPage,
              onTap: () => onPageChanged(page),
            ),
          );
        }),
        _PageButton(
          icon: Icons.chevron_right_rounded,
          enabled: currentPage < totalPages,
          onTap: () => onPageChanged(currentPage + 1),
        ),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
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

class _ViewDialog extends StatelessWidget {
  const _ViewDialog({required this.guide, required this.category});
  final PopularAppGuide guide;
  final AppCategory category;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
                          guide.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        _CategoryBadge(category: category),
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
              _ViewRow(label: 'Package', value: guide.packageName),
              _ViewRow(label: 'Store URL', value: guide.storeUrl),
              _ViewRow(label: 'Image URL', value: guide.urlImage ?? '—'),
              _ViewRow(label: 'Video URL', value: guide.urlVideo ?? '—'),
              _ViewRow(label: 'Description', value: guide.description ?? '—'),
              _ViewRow(label: 'Guide', value: guide.guide ?? '—'),
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

class _ViewRow extends StatelessWidget {
  const _ViewRow({required this.label, required this.value});
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
      title: const Text('Delete Guide'),
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
