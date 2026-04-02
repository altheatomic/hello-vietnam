import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import '../../domain/admin_food.dart';

/// Inline type CRUD dialog for the Food Management page.
/// Mirrors CategoryManagerDialog from Popular Apps.
class FoodTypeManagerDialog extends StatefulWidget {
  const FoodTypeManagerDialog({
    super.key,
    required this.initialTypes,
    required this.foodCountForType,
  });

  final List<FoodType> initialTypes;
  final Map<String, int> foodCountForType;

  @override
  State<FoodTypeManagerDialog> createState() => _FoodTypeManagerDialogState();
}

class _FoodTypeManagerDialogState extends State<FoodTypeManagerDialog> {
  late final List<FoodType> _types;
  String? _editingId;
  late final TextEditingController _editLabelCtrl;
  int _editColorIndex = 0;
  late final TextEditingController _addLabelCtrl;
  int _addColorIndex = 0;

  @override
  void initState() {
    super.initState();
    _types         = widget.initialTypes.map((t) => t).toList();
    _editLabelCtrl = TextEditingController();
    _addLabelCtrl  = TextEditingController();
  }

  @override
  void dispose() {
    _editLabelCtrl.dispose();
    _addLabelCtrl.dispose();
    super.dispose();
  }

  void _startEdit(FoodType t) => setState(() {
        _editingId          = t.id;
        _editColorIndex     = t.colorIndex;
        _editLabelCtrl.text = t.label;
      });

  void _cancelEdit() => setState(() => _editingId = null);

  void _saveEdit() {
    final label = _editLabelCtrl.text.trim();
    if (label.isEmpty) return;
    if (_types.any((t) =>
        t.id != _editingId &&
        t.label.toLowerCase() == label.toLowerCase())) {
      _snack('A type with this name already exists.');
      return;
    }
    setState(() {
      final idx = _types.indexWhere((t) => t.id == _editingId);
      if (idx != -1) {
        _types[idx] =
            _types[idx].copyWith(label: label, colorIndex: _editColorIndex);
      }
      _editingId = null;
    });
  }

  Future<void> _confirmDelete(FoodType t) async {
    if (_types.length <= 1) {
      _snack('At least one type must remain.');
      return;
    }
    final count    = widget.foodCountForType[t.id] ?? 0;
    final fallback = _types.firstWhere((x) => x.id != t.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirm(
        typeLabel:     t.label,
        foodCount:     count,
        fallbackLabel: fallback.label,
      ),
    );
    if (ok != true) return;
    setState(() {
      _types.removeWhere((x) => x.id == t.id);
      if (_editingId == t.id) _editingId = null;
    });
  }

  void _addType() {
    final label = _addLabelCtrl.text.trim();
    if (label.isEmpty) return;
    if (_types.any((t) => t.label.toLowerCase() == label.toLowerCase())) {
      _snack('A type with this name already exists.');
      return;
    }
    final raw = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final id = _types.any((t) => t.id == raw)
        ? '$raw-${DateTime.now().millisecondsSinceEpoch}'
        : raw;
    setState(() {
      _types.add(FoodType(id: id, label: label, colorIndex: _addColorIndex));
      _addLabelCtrl.clear();
      _addColorIndex = 0;
    });
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FtmHeader(onClose: () => Navigator.of(context).pop()),
            Flexible(
              child: _types.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('No types yet. Add one below.',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary)),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: AppColors.divider),
                      itemCount: _types.length,
                      itemBuilder: (_, i) {
                        final t = _types[i];
                        return t.id == _editingId
                            ? _FtmEditRow(
                                controller:     _editLabelCtrl,
                                colorIndex:     _editColorIndex,
                                onColorChanged: (ci) =>
                                    setState(() => _editColorIndex = ci),
                                onSave:   _saveEdit,
                                onCancel: _cancelEdit,
                              )
                            : _FtmDisplayRow(
                                type:      t,
                                isEditing: _editingId != null,
                                onEdit:    () => _startEdit(t),
                                onDelete:  () => _confirmDelete(t),
                              );
                      },
                    ),
            ),
            Divider(height: 1, color: AppColors.divider),
            _FtmAddFooter(
              controller:     _addLabelCtrl,
              colorIndex:     _addColorIndex,
              onColorChanged: (ci) => setState(() => _addColorIndex = ci),
              onAdd:          _addType,
            ),
            Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_types),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppConstants.buttonRadius)),
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

class _FtmHeader extends StatelessWidget {
  const _FtmHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.13),
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.cardRadius)),
      ),
      child: Row(
        children: [
          const Icon(Icons.restaurant_menu_outlined,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text('Manage Types',
              style: Theme.of(context).textTheme.headlineMedium),
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

// ── Display row ───────────────────────────────────────────────────────────────

class _FtmDisplayRow extends StatelessWidget {
  const _FtmDisplayRow({
    required this.type,
    required this.isEditing,
    required this.onEdit,
    required this.onDelete,
  });
  final FoodType type;
  final bool isEditing;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: type.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(type.label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ),
          Opacity(
            opacity: isEditing ? 0.3 : 1.0,
            child: Row(
              children: [
                _FtmRowBtn(
                    icon: Icons.edit_outlined,
                    tooltip: 'Rename',
                    color: AppColors.primaryDark,
                    onTap: isEditing ? null : onEdit),
                const SizedBox(width: 2),
                _FtmRowBtn(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete',
                    color: const Color(0xFFEF4444),
                    onTap: isEditing ? null : onDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit row ──────────────────────────────────────────────────────────────────

class _FtmEditRow extends StatelessWidget {
  const _FtmEditRow({
    required this.controller,
    required this.colorIndex,
    required this.onColorChanged,
    required this.onSave,
    required this.onCancel,
  });
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
          SizedBox(
            height: 38,
            child: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: ftmFieldDeco('Type name…'),
              onSubmitted: (_) => onSave(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...ftmColorDots(colorIndex, onColorChanged),
              const Spacer(),
              _FtmRowBtn(
                  icon: Icons.close_rounded,
                  tooltip: 'Cancel',
                  color: AppColors.textSecondary,
                  onTap: onCancel),
              const SizedBox(width: 4),
              _FtmRowBtn(
                  icon: Icons.check_rounded,
                  tooltip: 'Save',
                  color: AppColors.primary,
                  onTap: onSave),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add footer ────────────────────────────────────────────────────────────────

class _FtmAddFooter extends StatelessWidget {
  const _FtmAddFooter({
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
          Text('ADD TYPE',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 0.6, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(fontSize: 14),
                    decoration: ftmFieldDeco('New type name…'),
                    onSubmitted: (_) => onAdd(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 38,
                child: FilledButton(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppConstants.buttonRadius)),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Colour: ',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary)),
              const SizedBox(width: 6),
              ...ftmColorDots(colorIndex, onColorChanged),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Delete confirm ────────────────────────────────────────────────────────────

class _DeleteConfirm extends StatelessWidget {
  const _DeleteConfirm({
    required this.typeLabel,
    required this.foodCount,
    required this.fallbackLabel,
  });
  final String typeLabel, fallbackLabel;
  final int foodCount;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius)),
      title: const Text('Delete Type'),
      content: Text(
        foodCount > 0
            ? 'Delete "$typeLabel"?\n\n'
                '$foodCount food item${foodCount == 1 ? '' : 's'} '
                'using this type will be moved to "$fallbackLabel".'
            : 'Delete "$typeLabel"? This cannot be undone.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.buttonRadius)),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

InputDecoration ftmFieldDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary.withValues(alpha: 0.5)),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );

List<Widget> ftmColorDots(int selected, ValueChanged<int> onTap) =>
    List.generate(foodTypeColorPalette.length, (i) {
      final isSel = i == selected;
      return GestureDetector(
        onTap: () => onTap(i),
        child: AnimatedContainer(
          duration: AppConstants.defaultAnimation,
          width:  isSel ? 22 : 18,
          height: isSel ? 22 : 18,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: foodTypeColorPalette[i],
            shape: BoxShape.circle,
            border: isSel
                ? Border.all(color: AppColors.textPrimary, width: 2)
                : null,
          ),
        ),
      );
    });

class _FtmRowBtn extends StatefulWidget {
  const _FtmRowBtn({
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
  State<_FtmRowBtn> createState() => _FtmRowBtnState();
}

class _FtmRowBtnState extends State<_FtmRowBtn> {
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
