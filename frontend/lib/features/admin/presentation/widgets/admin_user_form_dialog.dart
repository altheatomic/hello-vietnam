import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import '../../domain/admin_user.dart';

// ── Add User dialog ───────────────────────────────────────────────────────────

/// Dialog for creating a new admin-managed user.
///
/// Returns a ready-to-insert [AdminUser] via `Navigator.pop`, or null on cancel.
/// Password is validated in-form but intentionally not stored on the model
/// (backend should receive it separately and hash it).
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
  final _phone    = TextEditingController();
  final _email    = TextEditingController();

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

    Navigator.of(context).pop(AdminUser(
      id:       'usr-${DateTime.now().millisecondsSinceEpoch}',
      fullName: _fullName.text.trim(),
      username: _username.text.trim(),
      email:    _email.text.trim(),
      phone:    _phone.text.trim(),
      role:     _role,
      status:   AdminUserStatus.active,
    ));
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
            // ── Header ────────────────────────────────────────────────
            _DialogHeader(
              title: 'Add User',
              onClose: () => Navigator.of(context).pop(),
            ),

            // ── Scrollable form body ──────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      const _FieldLabel(text: 'Full Name *'),
                      _FormField(
                        controller: _fullName,
                        hint: 'e.g. Nguyen Van A',
                        validator: _required('Full name'),
                      ),

                      const SizedBox(height: 16),

                      const _FieldLabel(text: 'Username *'),
                      _FormField(
                        controller: _username,
                        hint: 'e.g. nguyenvana',
                        validator: _required('Username'),
                      ),

                      const SizedBox(height: 16),

                      const _FieldLabel(text: 'Password *'),
                      _PasswordField(
                        controller: _password,
                        obscure: _obscurePassword,
                        onToggle: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        validator: _required('Password'),
                      ),

                      const SizedBox(height: 16),

                      const _FieldLabel(text: 'Role *'),
                      _RoleDropdown(
                        value: _role,
                        onChanged: (r) => setState(() => _role = r ?? _role),
                      ),

                      const SizedBox(height: 16),

                      const _FieldLabel(text: 'Phone'),
                      _FormField(
                        controller: _phone,
                        hint: 'e.g. 0901234567',
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 16),

                      const _FieldLabel(text: 'Email *'),
                      _FormField(
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

            // ── Footer ────────────────────────────────────────────────
            _DialogFooter(
              onCancel: () => Navigator.of(context).pop(),
              onSave: _onSave,
            ),
          ],
        ),
      ),
    );
  }

  // ── Validators ─────────────────────────────────────────────────────────────

  FormFieldValidator<String> _required(String name) =>
      (v) => (v == null || v.trim().isEmpty) ? '$name is required.' : null;

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required.';
    final emailRegex = RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email address.';
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
          Text('Add User', style: Theme.of(context).textTheme.headlineMedium),
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
  const _DialogFooter({required this.onCancel, required this.onSave});
  final VoidCallback onCancel, onSave;

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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
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
                borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            child: const Text('Add User'),
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
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary.withValues(alpha: 0.5),
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
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    );
  }
}

// ── Password field ────────────────────────────────────────────────────────────

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
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Enter password',
        hintStyle: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          onPressed: onToggle,
        ),
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

// ── Role dropdown ─────────────────────────────────────────────────────────────

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
      items: const [
        DropdownMenuItem(
          value: AdminUserRole.admin,
          child: Text('Admin'),
        ),
        DropdownMenuItem(
          value: AdminUserRole.user,
          child: Text('User'),
        ),
      ],
    );
  }
}
