import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  int _step = 0; // 0: email, 1: OTP, 2: new password, 3: success
  final _emailController = TextEditingController();
  final _otpControllers = List.generate(4, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(4, (_) => FocusNode());
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Resend timer
  int _resendSeconds = 60;
  Timer? _resendTimer;

  static const _illustrationUrl =
      'https://clzyqllrxiuelegukanu.supabase.co/storage/v1/object/sign/Image%20for%20FE/Login/ForgotPassword.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9hNDM4ZmU1My04MzcwLTQxMDAtOTlkOC1jMDhkMjI3NDQ1NmMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJJbWFnZSBmb3IgRkUvTG9naW4vRm9yZ290UGFzc3dvcmQucG5nIiwiaWF0IjoxNzcyNjI2MzA2LCJleHAiOjE4MDQxNjIzMDZ9.h2oWLRKqI4Wx0vxZKnLJ9H01JMY4otDXRIyC8VIkF9c';

  @override
  void dispose() {
    _emailController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 0) {
        timer.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    if (step == 1) _startResendTimer();
  }

  void _onConfirmEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Please enter your email');
      return;
    }
    _goToStep(1);
  }

  void _onConfirmOTP() {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 4) {
      _showSnack('Please enter the 4-digit code');
      return;
    }
    _goToStep(2);
  }

  void _onConfirmNewPassword() {
    final pw = _passwordController.text;
    final cpw = _confirmPasswordController.text;
    if (pw.isEmpty || cpw.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }
    if (pw != cpw) {
      _showSnack('Passwords do not match');
      return;
    }
    _resendTimer?.cancel();
    _goToStep(3);
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
                  child: Image.network(
                    _illustrationUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: totalHeight,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFFB3E5FC)),
                      );
                    },
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
                        _step == 2 ? 'Create new password' : 'Forgot Password',
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
                  ? _buildOTPStep()
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
          'Please enter your email to receive\nverification code',
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
        _buildMainButton('Confirm email', _onConfirmEmail),
      ],
    );
  }

  // ─── Step 1: OTP ───

  Widget _buildOTPStep() {
    final email = _emailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter your OTP',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Verification code sent to ',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            Text(
              email,
              style: const TextStyle(
                color: Color(0xFF42A5F5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            return Container(
              width: 35,
              height: 53,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: TextField(
                controller: _otpControllers[i],
                focusNode: _otpFocusNodes[i],
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                maxLines: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.5),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && i < 3) {
                    _otpFocusNodes[i + 1].requestFocus();
                  }
                  if (value.isEmpty && i > 0) {
                    _otpFocusNodes[i - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),

        const SizedBox(height: 24),
        _buildMainButton('Verify', _onConfirmOTP),
        const SizedBox(height: 20),

        // Resend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Resend code in ',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            Text(
              '00:${_resendSeconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Color(0xFF42A5F5),
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
        _buildMainButton('Continue', _onConfirmNewPassword),
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
            errorBuilder: (_, __, ___) => const Icon(
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
          child: _buildMainButton('Go to Home', () => context.go(AppRoutes.home)),
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

  Widget _buildMainButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB3E5FC),
          foregroundColor: const Color(0xFF1A1A2E),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
