import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hellovietnam/app/admin_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Figma palette
const _figmaBlue = Color(0xFF81D4FA);
// Panel backgrounds (both sides of the curve)
const _leftBg = Color(0x1A81D4FA); // #81D4FA at 10% opacity
const _rightBg = Color(0x6681D4FA); // #81D4FA at 40% opacity

// Curve line Figma spec: content 63.20dp, padding 70dp each side, border 70dp white each side
// Total visual slot = 63.20 + 70*2 + 70*2 = 343.20dp
// SVG file itself is 124px wide — we render it at its natural width, centered at 50% of screen
const _svgNaturalWidth = 124.0;

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  static const String _rememberKey = 'admin_login_remember';
  static const String _rememberedEmailKey = 'admin_login_email';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _emailError = false;
  bool _passwordError = false;
  bool _isLoading = false;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _restoreRememberedLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() {
      _emailError = false;
      _passwordError = false;
      _generalError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _emailError = email.isEmpty;
        _passwordError = password.isEmpty;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthRepository.instance.adminSignIn(
        email: email,
        password: password,
      );
      await _persistRememberedLogin(email);
      if (!mounted) return;
      context.go(AdminRoutes.dashboard);
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Login failed. Please try again.';
      if (e.toString().contains('NOT_ADMIN')) {
        errorMessage = 'Access denied. Only administrators can log in here.';
      } else if (e.toString().contains('Invalid login credentials')) {
        errorMessage = 'Invalid email or password.';
      } else if (e.toString().contains('USER_NOT_FOUND')) {
        errorMessage = 'User account not found.';
      }

      setState(() {
        _generalError = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberKey) ?? false;
    final email = prefs.getString(_rememberedEmailKey) ?? '';
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (remember && email.isNotEmpty) {
        _emailController.text = email;
      }
    });
  }

  Future<void> _persistRememberedLogin(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, _rememberMe);
    if (_rememberMe) {
      await prefs.setString(_rememberedEmailKey, email);
    } else {
      await prefs.remove(_rememberedEmailKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          // Curve is centered at the middle of the frame (50%)
          final curveCenter = totalWidth / 2;

          return Stack(
            children: [
              // ── Two equal panels ─────────────────────────────
              Row(
                children: [
                  // Left panel — light blue tint
                  Expanded(
                    child: Container(
                      color: _leftBg,
                      child: _LeftPanel(
                        emailController: _emailController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        rememberMe: _rememberMe,
                        emailError: _emailError,
                        passwordError: _passwordError,
                        generalError: _generalError,
                        isLoading: _isLoading,
                        onTogglePassword: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        onRememberMeChanged: (v) =>
                            setState(() => _rememberMe = v ?? false),
                        onEmailChanged: (_) {
                          if (_emailError) {
                            setState(() => _emailError = false);
                          }
                        },
                        onPasswordChanged: (_) {
                          if (_passwordError) {
                            setState(() => _passwordError = false);
                          }
                        },
                        onLogin: _handleLogin,
                      ),
                    ),
                  ),

                  // Right panel — medium blue tint
                  Expanded(
                    child: Container(
                      color: _rightBg,
                      child: const _RightPanel(),
                    ),
                  ),
                ],
              ),

              // ── SVG curve line centered at 50% of frame ──────
              Positioned(
                left: curveCenter - _svgNaturalWidth / 2,
                top: 0,
                bottom: 0,
                width: _svgNaturalWidth,
                child: SvgPicture.asset(
                  'assets/images/Auth_Image/curve line.svg',
                  fit: BoxFit.fill,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Left panel ────────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.rememberMe,
    required this.emailError,
    required this.passwordError,
    required this.generalError,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onRememberMeChanged,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onLogin,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool rememberMe;
  final bool emailError;
  final bool passwordError;
  final String? generalError;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool?> onRememberMeChanged;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Header ──────────────────────────────────────
              // "Welcome back!" — Smooch font (same as HelloVietnam)
              Text(
                'Welcome back!',
                textAlign: TextAlign.center,
                style: GoogleFonts.smooch(
                  fontSize: 65,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              // Subtitle centered directly below
              Text(
                'Login to your account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 40),

              // ── Form fields (full width, left-aligned labels) ─
              Align(
                alignment: Alignment.centerLeft,
                child: _FieldLabel(text: 'Email'),
              ),
              const SizedBox(height: 8),
              _LoginField(
                controller: emailController,
                hintText: 'Enter your email',
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                hasError: emailError,
                errorText: 'Please enter your email',
                onChanged: onEmailChanged,
              ),

              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerLeft,
                child: _FieldLabel(text: 'Password'),
              ),
              const SizedBox(height: 8),
              _LoginField(
                controller: passwordController,
                hintText: 'Enter your password',
                prefixIcon: Icons.lock_outline,
                obscureText: obscurePassword,
                hasError: passwordError,
                errorText: 'Please enter your password',
                onChanged: onPasswordChanged,
                suffixIcon: IconButton(
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Remember me — left-aligned
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: rememberMe,
                        onChanged: onRememberMeChanged,
                        activeColor: _figmaBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Remember me',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              if (generalError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    generalError!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _figmaBlue,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    disabledBackgroundColor: _figmaBlue.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Right panel ───────────────────────────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  const _RightPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Wanderly" — Smooch, 96sp, yellow, 457×153
            SizedBox(
              width: 457,
              height: 153,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'Wanderly',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.smooch(
                        fontSize: 96,
                        fontWeight: FontWeight.w400,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 10
                          ..color = Colors.white,
                      ),
                    ),
                    Text(
                      'Wanderly',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.smooch(
                        fontSize: 96,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFFDE510),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Illustration below Wanderly
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
              child: Image.asset(
                'assets/images/Auth_Image/LoginAdmin.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.hasError = false,
    this.errorText,
    this.onChanged,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool hasError;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError ? Colors.red : const Color(0xFFD1D5DB);
    final focusBorderColor = hasError ? Colors.red : _figmaBlue;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.6),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          prefixIcon,
          size: 20,
          color: hasError ? Colors.red.shade300 : AppColors.textSecondary,
        ),
        suffixIcon: suffixIcon,
        errorText: hasError ? errorText : null,
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: focusBorderColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}
