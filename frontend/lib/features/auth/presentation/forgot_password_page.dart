import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  int _step = 0; // 0: email, 1: check email, 2: new password, 3: success
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;
  StreamSubscription<AuthState>? _authSubscription;

  void _setLoading(bool loading) {
    setState(() => _isLoading = loading);
  }

  static const _illustrationAsset = 'assets/images/Auth_Image/Password.png';

  @override
  void initState() {
    super.initState();
    // Listen for auth state changes (when user clicks reset link)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      debugPrint('Auth state changed: ${data.event}, has session: ${session != null}');
      if (session != null && mounted) {
        // User has been authenticated via reset link, proceed to password step
        if (_step == 1) {
          _goToStep(2);
        } else if (_step == 0) {
          // If we're still on email step, jump to password step
          _goToStep(2);
        }
      }
    });

    // Check if user already has a valid session (from reset link)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentSession = Supabase.instance.client.auth.currentSession;
      debugPrint('Initial session check: ${currentSession != null}');
      if (currentSession != null && mounted) {
        // User already has session, go directly to password step
        _goToStep(2);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
  }

  void _onEmailLinkClicked() {
    // Check current session
    final currentSession = Supabase.instance.client.auth.currentSession;
    if (currentSession != null) {
      // User has been authenticated via reset link, proceed to password step
      _goToStep(2);
    } else {
      _showSnack('Please click the reset link in your email first, or try refreshing the page');
    }
  }

  void _refreshSession() async {
    _setLoading(true);
    try {
      // Force refresh session
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession != null) {
        _goToStep(2);
        _showSnack('Session verified! You can now set your new password.');
      } else {
        _showSnack('No active session found. Please click the reset link in your email.');
      }
    } catch (e) {
      _showSnack('Failed to verify session. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  void _resendResetEmail() async {
    _setLoading(true);
    try {
      final email = _emailController.text.trim();
      await AuthRepository.instance.resetPassword(email: email);
      _showSnack('Password reset email resent! Check your inbox.');
    } catch (e) {
      String errorMessage = 'Failed to resend email. Please try again.';
      final errorStr = e.toString();

      if (errorStr.contains('RATE_LIMIT:')) {
        errorMessage = errorStr.split('RATE_LIMIT:')[1].trim();
      } else if (errorStr.contains('INVALID_EMAIL:')) {
        errorMessage = errorStr.split('INVALID_EMAIL:')[1].trim();
      } else if (errorStr.contains('RESET_FAILED:')) {
        errorMessage = errorStr.split('RESET_FAILED:')[1].trim();
      } else if (errorStr.contains('rate limit') || errorStr.contains('Rate limit')) {
        errorMessage = 'Too many reset emails sent. Please wait 1 hour before trying again.';
      }

      _showSnack(errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  void _onConfirmEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Please enter your email');
      return;
    }

    // Basic email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showSnack('Please enter a valid email address');
      return;
    }

    _setLoading(true);
    try {
      await AuthRepository.instance.resetPassword(email: email);
      _showSnack('Password reset email sent! Check your inbox.');
      _goToStep(1);
    } catch (e) {
      String errorMessage = 'Failed to send reset email. Please try again.';
      final errorStr = e.toString();

      if (errorStr.contains('RATE_LIMIT:')) {
        errorMessage = errorStr.split('RATE_LIMIT:')[1].trim();
      } else if (errorStr.contains('INVALID_EMAIL:')) {
        errorMessage = errorStr.split('INVALID_EMAIL:')[1].trim();
      } else if (errorStr.contains('RESET_FAILED:')) {
        errorMessage = errorStr.split('RESET_FAILED:')[1].trim();
      } else if (errorStr.contains('rate limit') || errorStr.contains('Rate limit')) {
        errorMessage = 'Too many reset emails sent. Please wait 1 hour before trying again.';
      }

      _showSnack(errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  void _onConfirmNewPassword() async {
    // Check if user has a valid session (from reset link)
    final currentSession = Supabase.instance.client.auth.currentSession;
    if (currentSession == null) {
      _showSnack('Please click the reset link in your email first');
      return;
    }

    final pw = _passwordController.text;
    final cpw = _confirmPasswordController.text;

    if (pw.isEmpty || cpw.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }

    if (pw.length < 6) {
      _showSnack('Password must be at least 6 characters long');
      return;
    }

    if (pw != cpw) {
      _showSnack('Passwords do not match');
      return;
    }

    _setLoading(true);
    try {
      await AuthRepository.instance.updatePassword(newPassword: pw);
      _showSnack('Password updated successfully');
      _goToStep(3);
    } catch (e) {
      _showSnack('Failed to update password. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: _step == 3 ? _buildSuccessScreen(context) : _buildFormScreen(context),
      ),
    );
  }

  // ─── Form screens (step 0, 1, 2) ───

  Widget _buildFormScreen(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    const imageHeight = 380.0;
    final totalHeight = imageHeight + statusBarHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Illustration with overlaid title bar
        SizedBox(
          height: totalHeight,
          child: Stack(
            children: [
              // Full-width image behind status bar
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0.0, 0.75, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(
                    _illustrationAsset,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: totalHeight,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // Back button + title overlaid on image
              Positioned(
                top: statusBarHeight + 4,
                left: 4,
                right: 4,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_step > 0) {
                          setState(() => _step--);
                        } else {
                          context.pop();
                        }
                      },
                      icon: const Icon(Icons.chevron_left, size: 30, color: Colors.black87),
                    ),
                    Expanded(
                      child: Text(
                        _step == 2 ? 'Create new password' : 'Check your email',
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

        // Step content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _step == 0
              ? _buildEmailStep()
              : _step == 1
                  ? _buildEmailCheckStep()
                  : _buildNewPasswordStep(),
        ),

        const SizedBox(height: 50),
      ],
    );
  }

  // ─── Step 0: Email ───

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Please enter your email to receive\npassword reset link',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _emailController,
          hint: 'Enter your email',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        _buildMainButton('Confirm email', _onConfirmEmail, isLoading: _isLoading),
      ],
    );
  }

  // ─── Step 1: Check Email ───

  Widget _buildEmailCheckStep() {
    final email = _emailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'We\'ve sent a password reset link to\n'),
              TextSpan(
                text: email,
                style: const TextStyle(
                  color: Color(0xFF42A5F5),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '\n\n1. Click the link in your email\n2. You\'ll be redirected back here\n3. Click "I\'ve clicked the link" or "Refresh/Verify Session"'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Email icon
        const Center(
          child: Icon(
            Icons.email_outlined,
            size: 64,
            color: Color(0xFFB3E5FC),
          ),
        ),
        const SizedBox(height: 32),
        _buildMainButton('I\'ve clicked the link', _onEmailLinkClicked),
        const SizedBox(height: 16),
        _buildMainButton('Refresh/Verify Session', _refreshSession, isLoading: _isLoading),
        const SizedBox(height: 20),

        // Resend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Didn\'t receive the email? ',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            GestureDetector(
              onTap: _resendResetEmail,
              child: const Text(
                'Resend',
                style: TextStyle(
                  color: Color(0xFF42A5F5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Step 2: New Password ───

  Widget _buildNewPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Create your new password',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _passwordController,
          hint: 'Enter your password',
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.grey.shade400,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _confirmPasswordController,
          hint: 'Enter your password',
          icon: Icons.lock_outline,
          obscure: _obscureConfirmPassword,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.grey.shade400,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildMainButton('Continue', _onConfirmNewPassword, isLoading: _isLoading),
      ],
    );
  }

  // ─── Step 3: Success ───

  Widget _buildSuccessScreen(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: statusBarHeight + 60),

        // Success image
        Center(
          child: Image.network(
            'https://clzyqllrxiuelegukanu.supabase.co/storage/v1/object/sign/Image%20for%20FE/Login/Congratulation.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9hNDM4ZmU1My04MzcwLTQxMDAtOTlkOC1jMDhkMjI3NDQ1NmMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJJbWFnZSBmb3IgRkUvTG9naW4vQ29uZ3JhdHVsYXRpb24ucG5nIiwiaWF0IjoxNzcyNjMyOTA3LCJleHAiOjE4MDQxNjg5MDd9.84cG-9ErUL4ziuUO5kbCHOmdhPq9MqrCQFG9TZQ0z-k',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Color(0xFF42A5F5),
            ),
          ),
        ),

        const SizedBox(height: 40),

        const Text(
          'Congratulations!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your password has been created',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade500,
          ),
        ),

        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildMainButton(
            'Back to Login',
            () => context.go(AppRoutes.login),
          ),
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  // ─── Shared Widgets ───

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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

  Widget _buildMainButton(String label, VoidCallback onPressed, {bool isLoading = false}) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF81D4FA),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(label),
      ),
    );
  }
}
