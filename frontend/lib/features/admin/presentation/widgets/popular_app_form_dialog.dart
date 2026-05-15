import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import '../../domain/popular_app_guide.dart';

// ── Form dialog ───────────────────────────────────────────────────────────────

/// Create / Edit dialog for a [PopularAppGuide].
///
/// [initial]    — pre-populates the form (edit mode); null = create mode.
/// [categories] — the runtime category list, used to build the dropdown.
///
/// Returns a [PopularAppGuide] via `Navigator.pop` on save, or null on cancel.
class PopularAppFormDialog extends StatefulWidget {
  const PopularAppFormDialog({
    super.key,
    this.initial,
    required this.categories,
  });

  final PopularAppGuide? initial;
  final List<AppCategory> categories;

  @override
  State<PopularAppFormDialog> createState() => _PopularAppFormDialogState();
}

class _PopularAppFormDialogState extends State<PopularAppFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _packageName;
  late final TextEditingController _storeUrl;
  late final TextEditingController _urlImage;
  late final TextEditingController _urlVideo;
  late final TextEditingController _description;
  late final TextEditingController _guide;

  late String _categoryId;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final g = widget.initial;

    _name        = TextEditingController(text: g?.name        ?? '');
    _packageName = TextEditingController(text: g?.packageName ?? '');
    _storeUrl    = TextEditingController(text: g?.storeUrl    ?? '');
    _urlImage    = TextEditingController(text: g?.urlImage    ?? '');
    _urlVideo    = TextEditingController(text: g?.urlVideo    ?? '');
    _description = TextEditingController(text: g?.description ?? '');
    _guide       = TextEditingController(text: g?.guide       ?? '');

    // Resolve initial category — fall back to first available
    final firstId = widget.categories.isNotEmpty
        ? widget.categories.first.id
        : '';
    _categoryId = g?.categoryId ?? firstId;

    // Guard: if the saved categoryId no longer exists in the list, use first
    if (!widget.categories.any((c) => c.id == _categoryId)) {
      _categoryId = firstId;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _packageName.dispose();
    _storeUrl.dispose();
    _urlImage.dispose();
    _urlVideo.dispose();
    _description.dispose();
    _guide.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(PopularAppGuide(
      id:          widget.initial?.id ?? _generateId(),
      name:        _name.text.trim(),
      categoryId:  _categoryId,
      packageName: _packageName.text.trim(),
      storeUrl:    _storeUrl.text.trim(),
      urlImage:
          _urlImage.text.trim().isEmpty ? null : _urlImage.text.trim(),
      urlVideo:
          _urlVideo.text.trim().isEmpty ? null : _urlVideo.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      guide: _guide.text.trim().isEmpty ? null : _guide.text.trim(),
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
    ));
  }

  String _generateId() =>
      'guide-${DateTime.now().millisecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────
            _DialogHeader(
              title: _isEdit ? 'Edit Guide' : 'Add Guide',
              onClose: () => Navigator.of(context).pop(),
            ),

            // ── Scrollable form body ─────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      _FieldLabel(text: 'App Name *'),
                      _FormField(
                        controller: _name,
                        hint: 'e.g. Grab',
                        validator: _required('App name'),
                      ),

                      const SizedBox(height: 16),

                      _FieldLabel(text: 'Category *'),
                      _CategoryDropdown(
                        value: _categoryId,
                        categories: widget.categories,
                        onChanged: (id) =>
                            setState(() => _categoryId = id ?? _categoryId),
                      ),

                      const SizedBox(height: 16),

                      _FieldLabel(text: 'Package Name *'),
                      _FormField(
                        controller: _packageName,
                        hint: 'e.g. com.grabtaxi.passenger',
                        keyboardType: TextInputType.url,
                        validator: _validatePackage,
                        helperText:
                            'Find on Play Store URL: ?id=<package_name>',
                      ),

                      const SizedBox(height: 16),

                      _FieldLabel(text: 'Store URL *'),
                      _FormField(
                        controller: _storeUrl,
                        hint:
                            'https://play.google.com/store/apps/details?id=…',
                        keyboardType: TextInputType.url,
                        validator: _requiredUrl('Store URL'),
                      ),

                      const SizedBox(height: 16),

                      _FieldLabel(text: 'Image URL'),
                      _FormField(
                        controller: _urlImage,
                        hint: 'https://…/cover.jpg',
                        keyboardType: TextInputType.url,
                        validator: _optionalUrl,
                      ),

                      const SizedBox(height: 16),

                      _FieldLabel(text: 'Video URL  (optional)'),
                      _FormField(
                        controller: _urlVideo,
                        hint: 'https://…/guide.mp4',
                        keyboardType: TextInputType.url,
                        validator: _optionalUrl,
                      ),

                      const SizedBox(height: 16),

                      _FieldLabel(text: 'Description  (short teaser)'),
                      _FormField(
                        controller: _description,
                        hint: '1–3 sentences shown on the card.',
                        maxLines: 3,
                      ),

                      const SizedBox(height: 16),

                      _FieldLabel(text: 'Guide  (full how-to)'),
                      _FormField(
                        controller: _guide,
                        hint:
                            'Step-by-step instructions shown on the detail screen…',
                        maxLines: 6,
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────
            _DialogFooter(
              onCancel:  () => Navigator.of(context).pop(),
              onSave:    _onSave,
              saveLabel: _isEdit ? 'Save Changes' : 'Add Guide',
            ),
          ],
        ),
      ),
    );
  }

  // ── Validators ──────────────────────────────────────────────────────────────

  FormFieldValidator<String> _required(String name) =>
      (v) => (v == null || v.trim().isEmpty) ? '$name is required.' : null;

  String? _validatePackage(String? v) {
    if (v == null || v.trim().isEmpty) return 'Package name is required.';
    if (v.trim().contains(' '))        return 'No spaces allowed.';
    if (v.trim() != v.trim().toLowerCase()) {
      return 'Must be lowercase (e.g. com.example.app).';
    }
    return null;
  }

  FormFieldValidator<String> _requiredUrl(String name) => (v) {
    if (v == null || v.trim().isEmpty) return '$name is required.';
    if (!_isUrl(v.trim())) return 'Must start with https://';
    return null;
  };

  String? _optionalUrl(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!_isUrl(v.trim())) return 'Must start with https://';
    return null;
  }

  bool _isUrl(String s) =>
      s.startsWith('https://') || s.startsWith('http://');
}

// ── Dialog header ─────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title, required this.onClose});
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
          top: Radius.circular(AppConstants.cardRadius),
        ),
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

// ── Dialog footer ─────────────────────────────────────────────────────────────

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
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
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
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
                    BorderRadius.circular(AppConstants.buttonRadius),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
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
                    BorderRadius.circular(AppConstants.buttonRadius),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
            ),
            child: Text(saveLabel),
          ),
        ],
      ),
    );
  }
}

// ── Form field helpers ────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});
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

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.helperText,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final String? helperText;

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
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
        helperText: helperText,
        helperStyle: TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
        ),
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
          borderSide:
              const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    );
  }
}

// ── Category dropdown ─────────────────────────────────────────────────────────

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.value,
    required this.categories,
    required this.onChanged,
  });

  final String value;
  final List<AppCategory> categories;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Guard against empty list
    if (categories.isEmpty) {
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
          'No categories — add one via Manage Categories',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
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
      items: categories
          .map(
            (cat) => DropdownMenuItem(
              value: cat.id,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: cat.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(cat.label),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
