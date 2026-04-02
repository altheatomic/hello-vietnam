import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import '../../domain/admin_food.dart';

/// Create / Edit dialog for an [AdminFood].
/// Mirrors PopularAppFormDialog from Popular Apps.
///
/// [initial] — pre-populates the form (edit mode); null = create mode.
/// Returns an [AdminFood] via Navigator.pop on save, or null on cancel.
class FoodFormDialog extends StatefulWidget {
  const FoodFormDialog({
    super.key,
    this.initial,
    required this.types,
  });

  final AdminFood? initial;
  final List<FoodType> types;

  @override
  State<FoodFormDialog> createState() => _FoodFormDialogState();
}

class _FoodFormDialogState extends State<FoodFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _urlImage;
  late final TextEditingController _description;

  late String _typeId;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final f    = widget.initial;
    _name        = TextEditingController(text: f?.name        ?? '');
    _city        = TextEditingController(text: f?.city        ?? '');
    _urlImage    = TextEditingController(text: f?.urlImage    ?? '');
    _description = TextEditingController(text: f?.description ?? '');

    final firstId = widget.types.isNotEmpty ? widget.types.first.id : '';
    _typeId = f?.typeId ?? firstId;
    if (!widget.types.any((t) => t.id == _typeId)) _typeId = firstId;
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _urlImage.dispose();
    _description.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(AdminFood(
      id:          widget.initial?.id ?? 'food-${DateTime.now().millisecondsSinceEpoch}',
      name:        _name.text.trim(),
      typeId:      _typeId,
      city:        _city.text.trim(),
      urlImage:    _urlImage.text.trim().isEmpty ? null : _urlImage.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _FfdHeader(
              title:   _isEdit ? 'Edit Food' : 'Add Food',
              onClose: () => Navigator.of(context).pop(),
            ),

            // Scrollable form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      const _FfdLabel(text: 'Name *'),
                      _FfdField(
                        controller: _name,
                        hint: 'e.g. Phở Bò',
                        validator: _required('Name'),
                      ),

                      const SizedBox(height: 16),

                      const _FfdLabel(text: 'Type *'),
                      _FfdTypeDropdown(
                        value:    _typeId,
                        types:    widget.types,
                        onChanged: (id) =>
                            setState(() => _typeId = id ?? _typeId),
                      ),

                      const SizedBox(height: 16),

                      const _FfdLabel(text: 'City / Province *'),
                      _FfdField(
                        controller: _city,
                        hint: 'e.g. Hanoi',
                        validator: _required('City / Province'),
                      ),

                      const SizedBox(height: 16),

                      const _FfdLabel(text: 'Image URL'),
                      _FfdField(
                        controller: _urlImage,
                        hint: 'https://…/image.jpg',
                        keyboardType: TextInputType.url,
                        validator: _optionalUrl,
                      ),

                      const SizedBox(height: 16),

                      const _FfdLabel(text: 'Description'),
                      _FfdField(
                        controller: _description,
                        hint: 'Short description shown on the list…',
                        maxLines: 3,
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            _FfdFooter(
              onCancel:  () => Navigator.of(context).pop(),
              onSave:    _onSave,
              saveLabel: _isEdit ? 'Save Changes' : 'Add Food',
            ),
          ],
        ),
      ),
    );
  }

  // ── Validators ──────────────────────────────────────────────────────────────

  FormFieldValidator<String> _required(String name) =>
      (v) => (v == null || v.trim().isEmpty) ? '$name is required.' : null;

  String? _optionalUrl(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!v.trim().startsWith('https://') && !v.trim().startsWith('http://')) {
      return 'Must start with https://';
    }
    return null;
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _FfdHeader extends StatelessWidget {
  const _FfdHeader({required this.title, required this.onClose});
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.13),
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.cardRadius)),
      ),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
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

// ── Footer ────────────────────────────────────────────────────────────────────

class _FfdFooter extends StatelessWidget {
  const _FfdFooter({
    required this.onCancel,
    required this.onSave,
    required this.saveLabel,
  });
  final VoidCallback onCancel, onSave;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: AppColors.divider, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.buttonRadius)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.buttonRadius)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            child: Text(saveLabel),
          ),
        ],
      ),
    );
  }
}

// ── Field helpers ─────────────────────────────────────────────────────────────

class _FfdLabel extends StatelessWidget {
  const _FfdLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _FfdField extends StatelessWidget {
  const _FfdField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary.withValues(alpha: 0.5)),
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    );
  }
}

class _FfdTypeDropdown extends StatelessWidget {
  const _FfdTypeDropdown({
    required this.value,
    required this.types,
    required this.onChanged,
  });
  final String value;
  final List<FoodType> types;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) {
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          border: Border.all(color: AppColors.divider),
        ),
        alignment: Alignment.centerLeft,
        child: const Text(
          'No types — add one via Manage Types',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      validator: (v) =>
          (v == null || v.isEmpty) ? 'Type is required.' : null,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      ),
      items: types
          .map((t) => DropdownMenuItem(
                value: t.id,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: t.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(t.label),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
