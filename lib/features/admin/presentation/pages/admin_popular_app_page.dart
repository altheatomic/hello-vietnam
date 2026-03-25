import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import '../../data/popular_app_guide_mock_data.dart';
import '../../domain/popular_app_guide.dart';
import '../widgets/admin_section_header.dart';
import '../widgets/popular_app_form_dialog.dart';

// ── Page ─────────────────────────────────────────────────────────────────────

class AdminPopularAppPage extends StatefulWidget {
  const AdminPopularAppPage({super.key});

  @override
  State<AdminPopularAppPage> createState() => _AdminPopularAppPageState();
}

class _AdminPopularAppPageState extends State<AdminPopularAppPage> {
  late final List<PopularAppGuide> _guides =
      mockPopularAppGuides.map((g) => g).toList();

  final TextEditingController _searchController = TextEditingController();
  PopularAppCategory? _filterCategory;
  int _currentPage = 1;
  static const int _pageSize = 8;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filtering & pagination ─────────────────────────────────────────────────

  List<PopularAppGuide> get _filtered {
    final q = _searchController.text.toLowerCase().trim();
    return _guides.where((g) {
      final matchesSearch =
          q.isEmpty || g.name.toLowerCase().contains(q);
      final matchesCat =
          _filterCategory == null || g.category == _filterCategory;
      return matchesSearch && matchesCat;
    }).toList();
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

  void _onCategoryChanged(PopularAppCategory? cat) =>
      setState(() {
        _filterCategory = cat;
        _currentPage = 1;
      });

  // ── CRUD actions ───────────────────────────────────────────────────────────

  Future<void> _openCreate() async {
    final result = await showDialog<PopularAppGuide>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopularAppFormDialog(),
    );
    if (result == null) return;
    setState(() => _guides.insert(0, result));
    _showSnack('Guide "${result.name}" added.');
  }

  Future<void> _openEdit(PopularAppGuide guide) async {
    final result = await showDialog<PopularAppGuide>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopularAppFormDialog(initial: guide),
    );
    if (result == null) return;
    setState(() {
      final idx = _guides.indexWhere((g) => g.id == result.id);
      if (idx != -1) _guides[idx] = result;
    });
    _showSnack('Guide "${result.name}" updated.');
  }

  Future<void> _openView(PopularAppGuide guide) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ViewDialog(guide: guide),
    );
  }

  Future<void> _confirmDelete(PopularAppGuide guide) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirmDialog(name: guide.name),
    );
    if (confirmed != true) return;
    setState(() => _guides.removeWhere((g) => g.id == guide.id));
    _showSnack('Guide "${guide.name}" deleted.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final paged = _paged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        AdminSectionHeader(
          title: 'Popular App Guides',
          subtitle: 'Create and manage in-app guides for popular Vietnam apps',
          trailing: FilledButton.icon(
            onPressed: _openCreate,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Add Guide'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.buttonRadius),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        // ── Search + category filter bar ─────────────────────────────────────
        _CategoryFilterBar(
          controller: _searchController,
          selected: _filterCategory,
          onChanged: _onCategoryChanged,
          onSearchChanged: _onSearchChanged,
        ),

        const SizedBox(height: 16),

        // ── Table or empty state ─────────────────────────────────────────────
        if (filtered.isEmpty)
          EmptyState(
            icon: Icons.apps_outlined,
            message: 'No guides match your search.\nTry a different name or category.',
          )
        else ...[
          _GuideTable(
            guides: paged,
            onView: _openView,
            onEdit: _openEdit,
            onDelete: _confirmDelete,
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
    );
  }
}

// ── Search + filter bar ───────────────────────────────────────────────────────

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.controller,
    required this.selected,
    required this.onChanged,
    required this.onSearchChanged,
  });

  final TextEditingController controller;
  final PopularAppCategory? selected;
  final ValueChanged<PopularAppCategory?> onChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search pill — mirrors AdminSearchFilterBar pill style
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            ),
          ),
        ),

        const Spacer(),

        // Category filter chips
        _FilterChip(
          label: 'All',
          isSelected: selected == null,
          onTap: () => onChanged(null),
        ),
        const SizedBox(width: 6),
        ...PopularAppCategory.values.map((cat) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: _FilterChip(
            label: cat.label,
            isSelected: selected == cat,
            onTap: () => onChanged(selected == cat ? null : cat),
            color: _categoryColor(cat),
          ),
        )),
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
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final List<PopularAppGuide> guides;
  final ValueChanged<PopularAppGuide> onView;
  final ValueChanged<PopularAppGuide> onEdit;
  final ValueChanged<PopularAppGuide> onDelete;

  // Fixed column widths. Description column is Expanded.
  static const double _colName    = 200;
  static const double _colCat     = 116;
  static const double _colMedia   = 80;
  static const double _colPkg     = 200;
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
            // Header row
            _TableHeader(
              colName: _colName, colCat: _colCat,
              colMedia: _colMedia, colPkg: _colPkg, colActions: _colActions,
            ),
            // Data rows
            ...List.generate(guides.length, (i) => _GuideRow(
              guide: guides[i],
              isLast: i == guides.length - 1,
              onView: () => onView(guides[i]),
              onEdit: () => onEdit(guides[i]),
              onDelete: () => onDelete(guides[i]),
              colName: _colName, colCat: _colCat,
              colMedia: _colMedia, colPkg: _colPkg, colActions: _colActions,
            )),
          ],
        ),
      ),
    );
  }
}

// ── Table header ──────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.colName, required this.colCat, required this.colMedia,
    required this.colPkg, required this.colActions,
  });

  final double colName, colCat, colMedia, colPkg, colActions;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    return Container(
      height: 46,
      color: AppColors.primaryLight.withValues(alpha: 0.13),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _Cell(width: colName,    child: Text('App Name',    style: style)),
          const _ExpandedCell(     child: Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          _Cell(width: colCat,     child: Text('Category',    style: style)),
          _Cell(width: colMedia,   child: Text('Media',       style: style)),
          _Cell(width: colPkg,     child: Text('Package',     style: style)),
          _Cell(width: colActions, child: Text('Actions',     style: style)),
        ],
      ),
    );
  }
}

// ── Data row ──────────────────────────────────────────────────────────────────

class _GuideRow extends StatefulWidget {
  const _GuideRow({
    required this.guide, required this.isLast,
    required this.onView, required this.onEdit, required this.onDelete,
    required this.colName, required this.colCat, required this.colMedia,
    required this.colPkg, required this.colActions,
  });

  final PopularAppGuide guide;
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
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
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
            // App name + initial avatar
            _Cell(
              width: widget.colName,
              child: Row(
                children: [
                  _AppAvatar(name: g.name, category: g.category),
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

            // Category badge
            _Cell(
              width: widget.colCat,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _CategoryBadge(category: g.category),
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

            // Actions: view / edit / delete
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

class _AppAvatar extends StatelessWidget {
  const _AppAvatar({required this.name, required this.category});
  final String name;
  final PopularAppCategory category;

  @override
  Widget build(BuildContext context) {
    final bg = _categoryColor(category);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: bg.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: bg,
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});
  final PopularAppCategory category;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
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
      onExit:  (_) => setState(() => _hovered = false),
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
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const Spacer(),
        // Prev
        _PageButton(
          icon: Icons.chevron_left_rounded,
          enabled: currentPage > 1,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        const SizedBox(width: 4),
        // Page numbers
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
        // Next
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
  const _ViewDialog({required this.guide});
  final PopularAppGuide guide;

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
              // Header
              Row(
                children: [
                  _AppAvatar(name: guide.name, category: guide.category),
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
                        _CategoryBadge(category: guide.category),
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

              _ViewRow(label: 'Package',     value: guide.packageName),
              _ViewRow(label: 'Store URL',   value: guide.storeUrl),
              _ViewRow(label: 'Image URL',   value: guide.urlImage   ?? '—'),
              _ViewRow(label: 'Video URL',   value: guide.urlVideo   ?? '—'),
              _ViewRow(label: 'Description', value: guide.description ?? '—'),
              _ViewRow(label: 'Guide',       value: guide.guide       ?? '—'),

              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.buttonRadius),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 11),
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
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Delete confirmation dialog ────────────────────────────────────────────────

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

// ── Shared colour helper ──────────────────────────────────────────────────────

Color _categoryColor(PopularAppCategory cat) {
  switch (cat) {
    case PopularAppCategory.transport: return AppColors.primary;
    case PopularAppCategory.chat:      return const Color(0xFF22C55E);
    case PopularAppCategory.payment:   return const Color(0xFFF59E0B);
    case PopularAppCategory.delivery:  return const Color(0xFFF97316);
    case PopularAppCategory.other:     return AppColors.textSecondary;
  }
}
