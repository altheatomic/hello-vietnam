import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/features/admin/presentation/widgets/admin_form_components.dart';

import '../../domain/popular_app_guide.dart';

/// Create / Edit dialog for a [PopularAppGuide].
///
/// [initial] pre-populates the form in edit mode; null creates a new item.
/// [categories] is the runtime category list used to build the dropdown.
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
    final guide = widget.initial;

    _name = TextEditingController(text: guide?.name ?? '');
    _packageName = TextEditingController(text: guide?.packageName ?? '');
    _storeUrl = TextEditingController(text: guide?.storeUrl ?? '');
    _urlImage = TextEditingController(text: guide?.urlImage ?? '');
    _urlVideo = TextEditingController(text: guide?.urlVideo ?? '');
    _description = TextEditingController(text: guide?.description ?? '');
    _guide = TextEditingController(text: guide?.guide ?? '');

    final firstId = widget.categories.isNotEmpty ? widget.categories.first.id : '';
    _categoryId = guide?.categoryId ?? firstId;
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

    Navigator.of(context).pop(
      PopularAppGuide(
        id: widget.initial?.id ?? _generateId(),
        name: _name.text.trim(),
        categoryId: _categoryId,
        packageName: _packageName.text.trim(),
        storeUrl: _storeUrl.text.trim(),
        urlImage: _urlImage.text.trim().isEmpty ? null : _urlImage.text.trim(),
        urlVideo: _urlVideo.text.trim().isEmpty ? null : _urlVideo.text.trim(),
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        guide: _guide.text.trim().isEmpty ? null : _guide.text.trim(),
        createdAt: widget.initial?.createdAt ?? DateTime.now(),
      ),
    );
  }

  String _generateId() => 'guide-${DateTime.now().millisecondsSinceEpoch}';

  FormFieldValidator<String> _required(String name) =>
      (v) => (v == null || v.trim().isEmpty) ? '$name is required.' : null;

  String? _validatePackage(String? v) {
    if (v == null || v.trim().isEmpty) return 'Package name is required.';
    if (v.trim().contains(' ')) return 'No spaces allowed.';
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
            AdminDialogHeader(
              title: _isEdit ? 'Edit Guide' : 'Add Guide',
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const AdminFieldLabel(text: 'App Name *'),
                      AdminTextFormField(
                        controller: _name,
                        hint: 'e.g. Grab',
                        validator: _required('App name'),
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Category *'),
                      _CategoryDropdown(
                        value: _categoryId,
                        categories: widget.categories,
                        onChanged: (id) =>
                            setState(() => _categoryId = id ?? _categoryId),
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Package Name *'),
                      AdminTextFormField(
                        controller: _packageName,
                        hint: 'e.g. com.grabtaxi.passenger',
                        keyboardType: TextInputType.url,
                        validator: _validatePackage,
                        helperText: 'Find on Play Store URL: ?id=<package_name>',
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Store URL *'),
                      AdminTextFormField(
                        controller: _storeUrl,
                        hint: 'https://play.google.com/store/apps/details?id=...',
                        keyboardType: TextInputType.url,
                        validator: _requiredUrl('Store URL'),
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Image URL'),
                      AdminTextFormField(
                        controller: _urlImage,
                        hint: 'https://.../cover.jpg',
                        keyboardType: TextInputType.url,
                        validator: _optionalUrl,
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Video URL  (optional)'),
                      AdminTextFormField(
                        controller: _urlVideo,
                        hint: 'https://.../guide.mp4',
                        keyboardType: TextInputType.url,
                        validator: _optionalUrl,
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Description  (short teaser)'),
                      AdminTextFormField(
                        controller: _description,
                        hint: '1-3 sentences shown on the card.',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Guide  (full how-to)'),
                      AdminTextFormField(
                        controller: _guide,
                        hint: 'Step-by-step instructions shown on the detail screen...',
                        maxLines: 6,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            AdminDialogFooter(
              onCancel: () => Navigator.of(context).pop(),
              onSave: _onSave,
              saveLabel: _isEdit ? 'Save Changes' : 'Add Guide',
            ),
          ],
        ),
      ),
    );
  }
}

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
          'No categories - add one via Manage Categories',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: adminInputDecoration(),
      items: categories
          .map(
            (cat) => DropdownMenuItem(
              value: cat.id,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: cat.color, shape: BoxShape.circle),
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
