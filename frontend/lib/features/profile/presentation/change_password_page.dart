import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  static const String _illustrationAsset =
      'assets/images/Auth_Image/Password.png';

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSuccess = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.ui(message))));
  }

  void _onSave() {
    final String current = _currentPasswordController.text;
    final String next = _newPasswordController.text;
    final String confirm = _confirmPasswordController.text;

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }
    if (next != confirm) {
      _showSnack('New password and confirm password do not match');
      return;
    }
    if (current == next) {
      _showSnack('New password must be different from current password');
      return;
    }

    setState(() {
      _isSuccess = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: _isSuccess
            ? _buildSuccessScreen(context)
            : _buildChangePasswordForm(context),
      ),
    );
  }

  Widget _buildChangePasswordForm(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    const double imageHeight = 380;
    final double totalHeight = imageHeight + statusBarHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: totalHeight,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: <double>[0.0, 0.75, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(
                    _illustrationAsset,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: totalHeight,
                    alignment: Alignment.topCenter,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) => const SizedBox.shrink(),
                  ),
                ),
              ),
              Positioned(
                top: statusBarHeight + 4,
                left: 4,
                right: 4,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.chevron_left,
                        size: 30,
                        color: Colors.black87,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        context.l10n.ui('Change Password'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                context.l10n.ui('Change your password'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _currentPasswordController,
                hint: context.l10n.ui('Enter your current password'),
                icon: Icons.lock_outline,
                obscure: _obscureCurrent,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                  icon: Icon(
                    _obscureCurrent
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _newPasswordController,
                hint: context.l10n.ui('Enter your new password'),
                icon: Icons.lock_outline,
                obscure: _obscureNew,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  icon: Icon(
                    _obscureNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _confirmPasswordController,
                hint: context.l10n.ui('Confirm your new password'),
                icon: Icons.lock_outline,
                obscure: _obscureConfirm,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildMainButton(context.l10n.ui('Save'), _onSave),
            ],
          ),
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildSuccessScreen(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: statusBarHeight + 60),
        Center(
          child: Image.network(
            'https://clzyqllrxiuelegukanu.supabase.co/storage/v1/object/sign/Image%20for%20FE/Login/Congratulation.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9hNDM4ZmU1My04MzcwLTQxMDAtOTlkOC1jMDhkMjI3NDQ1NmMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJJbWFnZSBmb3IgRkUvTG9naW4vQ29uZ3JhdHVsYXRpb24ucG5nIiwiaWF0IjoxNzcyNjMyOTA3LCJleHAiOjE4MDQxNjg5MDd9.84cG-9ErUL4ziuUO5kbCHOmdhPq9MqrCQFG9TZQ0z-k',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) =>
                    const Icon(
                      Icons.check_circle_outline,
                      size: 80,
                      color: Color(0xFF42A5F5),
                    ),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          context.l10n.ui('Congratulations!'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.ui('Your password has been changed'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildMainButton(
            context.l10n.ui('Back to Login'),
            () => context.go(AppRoutes.login),
          ),
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: Colors.grey.shade400),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.lightBlue.shade300, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildMainButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF81D4FA),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
