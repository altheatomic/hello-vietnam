import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/features/admin/presentation/widgets/admin_form_components.dart';

import '../../domain/admin_food.dart';

/// Create / Edit dialog for an [AdminFood].
///
/// [initial] pre-populates the form in edit mode; null creates a new item.
/// Returns an [AdminFood] via `Navigator.pop` on save, or null on cancel.
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
    final food = widget.initial;
    _name = TextEditingController(text: food?.name ?? '');
    _city = TextEditingController(text: food?.city ?? '');
    _urlImage = TextEditingController(text: food?.urlImage ?? '');
    _description = TextEditingController(text: food?.description ?? '');

    final firstId = widget.types.isNotEmpty ? widget.types.first.id : '';
    _typeId = food?.typeId ?? firstId;
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

    Navigator.of(context).pop(
      AdminFood(
        id: widget.initial?.id ?? 'food-${DateTime.now().millisecondsSinceEpoch}',
        name: _name.text.trim(),
        typeId: _typeId,
        city: _city.text.trim(),
        urlImage: _urlImage.text.trim().isEmpty ? null : _urlImage.text.trim(),
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
      ),
    );
  }

  FormFieldValidator<String> _required(String name) =>
      (v) => (v == null || v.trim().isEmpty) ? '$name is required.' : null;

  String? _optionalUrl(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!v.trim().startsWith('https://') && !v.trim().startsWith('http://')) {
      return 'Must start with https://';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: _isEdit ? 'Edit Food' : 'Add Food',
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
                      const AdminFieldLabel(text: 'Name *'),
                      AdminTextFormField(
                        controller: _name,
                        hint: 'e.g. Pho Bo',
                        validator: _required('Name'),
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Type *'),
                      _FfdTypeDropdown(
                        value: _typeId,
                        types: widget.types,
                        onChanged: (id) => setState(() => _typeId = id ?? _typeId),
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'City / Province *'),
                      AdminTextFormField(
                        controller: _city,
                        hint: 'e.g. Hanoi',
                        validator: _required('City / Province'),
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Image URL'),
                      AdminTextFormField(
                        controller: _urlImage,
                        hint: 'https://.../image.jpg',
                        keyboardType: TextInputType.url,
                        validator: _optionalUrl,
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Description'),
                      AdminTextFormField(
                        controller: _description,
                        hint: 'Short description shown on the list...',
                        maxLines: 3,
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
              saveLabel: _isEdit ? 'Save Changes' : 'Add Food',
            ),
          ],
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
          'No types - add one via Manage Types',
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
      decoration: adminInputDecoration(),
      items: types
          .map(
            (t) => DropdownMenuItem(
              value: t.id,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: t.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(t.label),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
