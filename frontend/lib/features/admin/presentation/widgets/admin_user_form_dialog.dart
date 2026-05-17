import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/features/admin/presentation/widgets/admin_form_components.dart';

import '../../domain/admin_user.dart';

/// Dialog for creating a new admin-managed user.
///
/// Returns a ready-to-insert [AdminUser] via `Navigator.pop`, or null on cancel.
/// Password is validated in-form but intentionally not stored on the model.
class AdminUserFormDialog extends StatefulWidget {
  const AdminUserFormDialog({super.key});

  @override
  State<AdminUserFormDialog> createState() => _AdminUserFormDialogState();
}

class _AdminUserFormDialogState extends State<AdminUserFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  AdminUserRole _role = AdminUserRole.user;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _password.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      AdminUser(
        id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
        fullName: _fullName.text.trim(),
        username: _username.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        role: _role,
        status: AdminUserStatus.active,
      ),
    );
  }

  FormFieldValidator<String> _required(String name) =>
      (v) => (v == null || v.trim().isEmpty) ? '$name is required.' : null;

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required.';
    final emailRegex = RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email address.';
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
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: 'Add User',
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
                      const AdminFieldLabel(text: 'Full Name *'),
                      AdminTextFormField(
                        controller: _fullName,
                        hint: 'e.g. Nguyen Van A',
                        validator: _required('Full name'),
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Username *'),
                      AdminTextFormField(
                        controller: _username,
                        hint: 'e.g. nguyenvana',
                        validator: _required('Username'),
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Password *'),
                      _PasswordField(
                        controller: _password,
                        obscure: _obscurePassword,
                        onToggle: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        validator: _required('Password'),
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Role *'),
                      _RoleDropdown(
                        value: _role,
                        onChanged: (r) => setState(() => _role = r ?? _role),
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Phone'),
                      AdminTextFormField(
                        controller: _phone,
                        hint: 'e.g. 0901234567',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      const AdminFieldLabel(text: 'Email *'),
                      AdminTextFormField(
                        controller: _email,
                        hint: 'e.g. user@email.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
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
              saveLabel: 'Add User',
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    required this.validator,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return AdminTextFormField(
      controller: controller,
      hint: 'Enter password',
      obscureText: obscure,
      validator: validator,
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 18,
          color: AppColors.textSecondary,
        ),
        onPressed: onToggle,
      ),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({required this.value, required this.onChanged});

  final AdminUserRole value;
  final ValueChanged<AdminUserRole?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AdminUserRole>(
      initialValue: value,
      onChanged: onChanged,
      validator: (v) => v == null ? 'Role is required.' : null,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: adminInputDecoration(),
      items: const [
        DropdownMenuItem(
          value: AdminUserRole.user,
          child: Text('User'),
        ),
        DropdownMenuItem(
          value: AdminUserRole.admin,
          child: Text('Admin'),
        ),
      ],
    );
  }
}
