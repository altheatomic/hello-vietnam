import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import '../../domain/popular_app_guide.dart';

// ── Dialog ────────────────────────────────────────────────────────────────────

/// Inline category CRUD dialog, opened from the Popular App Guides page.
///
/// Works on a LOCAL COPY of [initialCategories].
/// Returns the updated [List<AppCategory>] when "Done" is pressed,
/// or null if the user dismisses with the × button.
///
/// The parent page is responsible for reassigning guides whose category
/// was deleted (it can diff the old vs new ID sets).
class CategoryManagerDialog extends StatefulWidget {
  const CategoryManagerDialog({
    super.key,
    required this.initialCategories,
    required this.guideCountForCategory,
  });

  final List<AppCategory> initialCategories;

  /// Maps categoryId → number of guides using it, so the delete confirmation
  /// can tell admin how many guides will be reassigned.
  final Map<String, int> guideCountForCategory;

  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  late final List<AppCategory> _categories;

  /// ID of the category row currently open for inline editing (null = none).
  String? _editingId;

  /// Inline edit controllers
  late final TextEditingController _editLabelCtrl;
  int _editColorIndex = 0;

  /// "Add category" footer controller
  late final TextEditingController _addLabelCtrl;
  int _addColorIndex = 0;

  @override
  void initState() {
    super.initState();
    _categories = widget.initialCategories.map((c) => c).toList();
    _editLabelCtrl = TextEditingController();
    _addLabelCtrl  = TextEditingController();
  }

  @override
  void dispose() {
    _editLabelCtrl.dispose();
    _addLabelCtrl.dispose();
    super.dispose();
  }

  // ── Edit row ──────────────────────────────────────────────────────────────

  void _startEdit(AppCategory cat) {
    setState(() {
      _editingId    = cat.id;
      _editColorIndex = cat.colorIndex;
      _editLabelCtrl.text = cat.label;
    });
  }

  void _cancelEdit() => setState(() => _editingId = null);

  void _saveEdit() {
    final label = _editLabelCtrl.text.trim();
    if (label.isEmpty) return;
    setState(() {
      final idx = _categories.indexWhere((c) => c.id == _editingId);
      if (idx != -1) {
        _categories[idx] = _categories[idx]
            .copyWith(label: label, colorIndex: _editColorIndex);
      }
      _editingId = null;
    });
  }

  // ── Delete row ────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(AppCategory cat) async {
    // Prevent deleting the last category
    if (_categories.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one category must remain.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final guideCount = widget.guideCountForCategory[cat.id] ?? 0;
    final fallback   = _categories.firstWhere((c) => c.id != cat.id);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteCategoryConfirm(
        categoryLabel: cat.label,
        guideCount:    guideCount,
        fallbackLabel: fallback.label,
      ),
    );

    if (confirmed != true) return;
    setState(() {
      _categories.removeWhere((c) => c.id == cat.id);
      if (_editingId == cat.id) _editingId = null;
    });
  }

  // ── Add category ──────────────────────────────────────────────────────────

  void _addCategory() {
    final label = _addLabelCtrl.text.trim();
    if (label.isEmpty) return;

    // Generate a URL-safe ID from the label
    final id = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    // Deduplicate ID if it already exists
    final finalId = _categories.any((c) => c.id == id)
        ? '$id-${DateTime.now().millisecondsSinceEpoch}'
        : id;

    setState(() {
      _categories.add(AppCategory(
        id:         finalId,
        label:      label,
        colorIndex: _addColorIndex,
      ));
      _addLabelCtrl.clear();
      _addColorIndex = 0;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ────────────────────────────────────────────
            _DialogHeader(onClose: () => Navigator.of(context).pop()),

            // ── Category list ─────────────────────────────────────
            Flexible(
              child: _categories.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No categories yet. Add one below.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: AppColors.divider),
                      itemCount: _categories.length,
                      itemBuilder: (_, i) {
                        final cat = _categories[i];
                        return cat.id == _editingId
                            ? _EditRow(
                                category:   cat,
                                controller: _editLabelCtrl,
                                colorIndex: _editColorIndex,
                                onColorChanged: (ci) =>
                                    setState(() => _editColorIndex = ci),
                                onSave:   _saveEdit,
                                onCancel: _cancelEdit,
                              )
                            : _DisplayRow(
                                category:    cat,
                                isEditing:   _editingId != null,
                                onEdit:   () => _startEdit(cat),
                                onDelete: () => _confirmDelete(cat),
                              );
                      },
                    ),
            ),

            Divider(height: 1, color: AppColors.divider),

            // ── Add category footer ───────────────────────────────
            _AddCategoryFooter(
              controller:    _addLabelCtrl,
              colorIndex:    _addColorIndex,
              onColorChanged: (ci) => setState(() => _addColorIndex = ci),
              onAdd:         _addCategory,
            ),

            Divider(height: 1, color: AppColors.divider),

            // ── Done button ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_categories),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.buttonRadius),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 11),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    child: const Text('Done'),
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

// ── Header ────────────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.13),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.cardRadius),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.category_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            'Manage Categories',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

// ── Display row (read mode) ───────────────────────────────────────────────────

class _DisplayRow extends StatelessWidget {
  const _DisplayRow({
    required this.category,
    required this.isEditing,
    required this.onEdit,
    required this.onDelete,
  });

  final AppCategory category;
  final bool isEditing; // another row is being edited — dim actions
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          // Colour dot
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          // Label
          Expanded(
            child: Text(
              category.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // Actions — dimmed when another row is in edit mode
          Opacity(
            opacity: isEditing ? 0.3 : 1.0,
            child: Row(
              children: [
                _RowIconBtn(
                  icon: Icons.edit_outlined,
                  tooltip: 'Rename',
                  color: AppColors.primaryDark,
                  onTap: isEditing ? null : onEdit,
                ),
                const SizedBox(width: 2),
                _RowIconBtn(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete',
                  color: const Color(0xFFEF4444),
                  onTap: isEditing ? null : onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit row (inline edit mode) ───────────────────────────────────────────────

class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.category,
    required this.controller,
    required this.colorIndex,
    required this.onColorChanged,
    required this.onSave,
    required this.onCancel,
  });

  final AppCategory category;
  final TextEditingController controller;
  final int colorIndex;
  final ValueChanged<int> onColorChanged;
  final VoidCallback onSave, onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label text field
          SizedBox(
            height: 38,
            child: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Category name…',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.buttonRadius),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.buttonRadius),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.buttonRadius),
                  borderSide:
                      BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onSubmitted: (_) => onSave(),
            ),
          ),
          const SizedBox(height: 8),
          // Colour palette + save/cancel
          Row(
            children: [
              // Colour picker dots
              ...List.generate(categoryColorPalette.length, (i) {
                final isSelected = i == colorIndex;
                return GestureDetector(
                  onTap: () => onColorChanged(i),
                  child: AnimatedContainer(
                    duration: AppConstants.defaultAnimation,
                    width: isSelected ? 22 : 18,
                    height: isSelected ? 22 : 18,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: categoryColorPalette[i],
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: AppColors.textPrimary,
                              width: 2,
                            )
                          : null,
                    ),
                  ),
                );
              }),
              const Spacer(),
              // Cancel
              _RowIconBtn(
                icon: Icons.close_rounded,
                tooltip: 'Cancel',
                color: AppColors.textSecondary,
                onTap: onCancel,
              ),
              const SizedBox(width: 4),
              // Save
              _RowIconBtn(
                icon: Icons.check_rounded,
                tooltip: 'Save',
                color: AppColors.primary,
                onTap: onSave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add category footer ───────────────────────────────────────────────────────

class _AddCategoryFooter extends StatelessWidget {
  const _AddCategoryFooter({
    required this.controller,
    required this.colorIndex,
    required this.onColorChanged,
    required this.onAdd,
  });

  final TextEditingController controller;
  final int colorIndex;
  final ValueChanged<int> onColorChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADD CATEGORY',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Name field
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'New category name…',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.buttonRadius),
                        borderSide: BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.buttonRadius),
                        borderSide: BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.buttonRadius),
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => onAdd(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Add button
              SizedBox(
                height: 38,
                child: FilledButton(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.buttonRadius),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Colour picker for new category
          Row(
            children: [
              Text(
                'Colour: ',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              ...List.generate(categoryColorPalette.length, (i) {
                final isSelected = i == colorIndex;
                return GestureDetector(
                  onTap: () => onColorChanged(i),
                  child: AnimatedContainer(
                    duration: AppConstants.defaultAnimation,
                    width: isSelected ? 22 : 18,
                    height: isSelected ? 22 : 18,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: categoryColorPalette[i],
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: AppColors.textPrimary,
                              width: 2,
                            )
                          : null,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Delete confirmation ───────────────────────────────────────────────────────

class _DeleteCategoryConfirm extends StatelessWidget {
  const _DeleteCategoryConfirm({
    required this.categoryLabel,
    required this.guideCount,
    required this.fallbackLabel,
  });

  final String categoryLabel;
  final int guideCount;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      title: const Text('Delete Category'),
      content: Text(
        guideCount > 0
            ? 'Delete "$categoryLabel"?\n\n'
              '$guideCount guide${guideCount == 1 ? '' : 's'} currently '
              'using this category will be moved to "$fallbackLabel".'
            : 'Delete "$categoryLabel"? This cannot be undone.',
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

// ── Shared icon button ────────────────────────────────────────────────────────

class _RowIconBtn extends StatefulWidget {
  const _RowIconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<_RowIconBtn> createState() => _RowIconBtnState();
}

class _RowIconBtnState extends State<_RowIconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppConstants.defaultAnimation,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _hovered && widget.onTap != null
                  ? widget.color.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 16, color: widget.color),
          ),
        ),
      ),
    );
  }
}
