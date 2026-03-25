import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import '../../domain/popular_app_guide.dart';

// ── Form dialog ───────────────────────────────────────────────────────────────

/// Create / Edit dialog for a [PopularAppGuide].
///
/// Pass [initial] to pre-populate the form (edit mode).
/// Leave [initial] null for create mode.
///
/// Returns a [PopularAppGuide] via `Navigator.pop` on save, or null on cancel.
class PopularAppFormDialog extends StatefulWidget {
  const PopularAppFormDialog({super.key, this.initial});

  final PopularAppGuide? initial;

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

  late PopularAppCategory _category;

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
    _category    = g?.category ?? PopularAppCategory.transport;
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

    final result = PopularAppGuide(
      id:          widget.initial?.id   ?? _generateId(),
      name:        _name.text.trim(),
      category:    _category,
      packageName: _packageName.text.trim(),
      storeUrl:    _storeUrl.text.trim(),
      urlImage:    _urlImage.text.trim().isEmpty ? null : _urlImage.text.trim(),
      urlVideo:    _urlVideo.text.trim().isEmpty ? null : _urlVideo.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      guide:       _guide.text.trim().isEmpty ? null : _guide.text.trim(),
      createdAt:   widget.initial?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(result);
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
            // ── Dialog header ──────────────────────────────────────────
            _DialogHeader(
              title: _isEdit ? 'Edit Guide' : 'Add Guide',
              onClose: () => Navigator.of(context).pop(),
            ),

            // ── Scrollable form body ───────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // App name
                      _FieldLabel(text: 'App Name *'),
                      _FormField(
                        controller: _name,
                        hint: 'e.g. Grab',
                        validator: _requiredValidator('App name'),
                      ),

                      const SizedBox(height: 16),

                      // Category
                      _FieldLabel(text: 'Category *'),
                      _CategoryDropdown(
                        value: _category,
                        onChanged: (cat) => setState(() => _category = cat!),
                      ),

                      const SizedBox(height: 16),

                      // Package name
                      _FieldLabel(text: 'Package Name *'),
                      _FormField(
                        controller: _packageName,
                        hint: 'e.g. com.grabtaxi.passenger',
                        keyboardType: TextInputType.url,
                        validator: _packageValidator,
                        helperText:
                            'Find on Play Store URL: ?id=<package_name>',
                      ),

                      const SizedBox(height: 16),

                      // Store URL
                      _FieldLabel(text: 'Store URL *'),
                      _FormField(
                        controller: _storeUrl,
                        hint: 'https://play.google.com/store/apps/details?id=…',
                        keyboardType: TextInputType.url,
                        validator: _urlValidator('Store URL'),
                      ),

                      const SizedBox(height: 16),

                      // Image URL
                      _FieldLabel(text: 'Image URL'),
                      _FormField(
                        controller: _urlImage,
                        hint: 'https://…/cover.jpg',
                        keyboardType: TextInputType.url,
                        validator: _optionalUrlValidator,
                      ),

                      const SizedBox(height: 16),

                      // Video URL (optional)
                      _FieldLabel(text: 'Video URL  (optional)'),
                      _FormField(
                        controller: _urlVideo,
                        hint: 'https://…/guide.mp4',
                        keyboardType: TextInputType.url,
                        validator: _optionalUrlValidator,
                      ),

                      const SizedBox(height: 16),

                      // Short description
                      _FieldLabel(text: 'Description  (short teaser)'),
                      _FormField(
                        controller: _description,
                        hint: '1–3 sentences shown on the card.',
                        maxLines: 3,
                      ),

                      const SizedBox(height: 16),

                      // Full guide
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

            // ── Footer actions ─────────────────────────────────────────
            _DialogFooter(
              onCancel: () => Navigator.of(context).pop(),
              onSave: _onSave,
              saveLabel: _isEdit ? 'Save Changes' : 'Add Guide',
            ),
          ],
        ),
      ),
    );
  }

  // ── Validators ─────────────────────────────────────────────────────────────

  FormFieldValidator<String> _requiredValidator(String fieldName) =>
      (v) => (v == null || v.trim().isEmpty) ? '$fieldName is required.' : null;

  String? _packageValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Package name is required.';
    final trimmed = v.trim();
    if (trimmed.contains(' ')) return 'Package name must not contain spaces.';
    if (trimmed != trimmed.toLowerCase()) {
      return 'Package name must be lowercase (e.g. com.example.app).';
    }
    return null;
  }

  FormFieldValidator<String> _urlValidator(String fieldName) => (v) {
    if (v == null || v.trim().isEmpty) return '$fieldName is required.';
    if (!v.trim().startsWith('https://') && !v.trim().startsWith('http://')) {
      return 'Must start with https://';
    }
    return null;
  };

  String? _optionalUrlValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    if (!v.trim().startsWith('https://') && !v.trim().startsWith('http://')) {
      return 'Must start with https://';
    }
    return null;
  }
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
                borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
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
                borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
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

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.value,
    required this.onChanged,
  });

  final PopularAppCategory value;
  final ValueChanged<PopularAppCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<PopularAppCategory>(
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
      items: PopularAppCategory.values
          .map(
            (cat) => DropdownMenuItem(
              value: cat,
              child: Text(cat.label),
            ),
          )
          .toList(),
    );
  }
}
