import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String loginErrorMessage(Object error) {
  if (error is AuthException &&
      error.message.toLowerCase().contains('invalid login credentials')) {
    return 'Incorrect email or password';
  }
  return 'Failed to sign in. Please try again.';
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String _loginImageAsset = 'assets/images/Auth_Image/Login.png';
  static const String _googleLogoAsset = 'assets/images/Auth_Image/LogoGG.png';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _emailError = false;
  bool _passwordError = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    AuthRepository.instance.addListener(_handleAuthChanged);
  }

  @override
  void dispose() {
    AuthRepository.instance.removeListener(_handleAuthChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleAuthChanged() {
    if (!mounted || !AuthRepository.instance.isLoggedIn) return;
    context.go(AppRoutes.home);
  }

  void _onContinue() async {
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
      await AuthRepository.instance.signIn(email: email, password: password);
      if (!mounted) return;
      context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loginErrorMessage(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      await AuthRepository.instance.signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.ui('Google sign in failed')}: ${e.toString()}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onForgotPassword() {
    context.push(AppRoutes.forgotPassword);
  }

  void _onCreateAccount() {
    context.push(AppRoutes.register);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Scrollable content
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top illustration ──
                _buildIllustration(context),

                // ── Form section ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),

                      // Title
                      _buildTitle(),

                      const SizedBox(height: 28),

                      // Email field
                      _buildEmailField(),

                      const SizedBox(height: 16),

                      // Password field
                      _buildPasswordField(),

                      const SizedBox(height: 12),

                      // Remember me + Forgot password
                      _buildRememberRow(),

                      const SizedBox(height: 24),

                      // Continue button
                      _buildContinueButton(),

                      const SizedBox(height: 20),

                      // Or divider
                      _buildOrDivider(),

                      const SizedBox(height: 20),

                      // Google button
                      _buildGoogleButton(),

                      const SizedBox(height: 28),

                      // Create account link
                      _buildCreateAccountLink(),

                      const SizedBox(height: 70),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UI Components
  // ─────────────────────────────────────────────

  Widget _buildIllustration(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Image container
        Container(
          width: double.infinity,
          height: 350 + statusBarHeight,
          color: const Color(0xFFB3E5FC),
          child: Image.asset(
            _loginImageAsset,
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(
                  Icons.flight_takeoff,
                  size: 80,
                  color: Colors.white,
                ),
              );
            },
          ),
        ),

        // White oval curve at the bottom
        Positioned(
          bottom: -30,
          left: -20,
          right: -20,
          child: Container(
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.elliptical(200, 50),
                topRight: Radius.elliptical(200, 50),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          context.l10n.ui('Login to Start Your'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.3,
          ),
        ),
        Text(
          context.l10n.ui('Amazing Trips'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.lightBlue.shade300,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      onChanged: (_) {
        if (_emailError) setState(() => _emailError = false);
      },
      decoration: InputDecoration(
        hintText: context.l10n.ui('Enter your email'),
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(
          Icons.mail_outline,
          color: _emailError ? Colors.red.shade300 : Colors.grey.shade400,
        ),
        errorText: _emailError
            ? context.l10n.ui('Please enter your email')
            : null,
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: _emailError ? Colors.red : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: _emailError ? Colors.red : Colors.lightBlue.shade300,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      onChanged: (_) {
        if (_passwordError) setState(() => _passwordError = false);
      },
      decoration: InputDecoration(
        hintText: context.l10n.ui('Enter your password'),
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(
          Icons.lock_outline,
          color: _passwordError ? Colors.red.shade300 : Colors.grey.shade400,
        ),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.grey.shade400,
          ),
        ),
        errorText: _passwordError
            ? context.l10n.ui('Please enter your password')
            : null,
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: _passwordError ? Colors.red : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: _passwordError ? Colors.red : Colors.lightBlue.shade300,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildRememberRow() {
    return Row(
      children: [
        // Remember me
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _rememberMe,
            onChanged: (v) => setState(() => _rememberMe = v ?? false),
            activeColor: Colors.lightBlue.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          context.l10n.ui('Remember me'),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),

        const Spacer(),

        // Forgot password
        GestureDetector(
          onTap: _onForgotPassword,
          child: Text(
            context.l10n.ui('Forgot password?'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF81D4FA),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : Text(context.l10n.ui('Login')),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.l10n.ui('Or'),
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _onGoogleSignIn,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        icon: Image.asset(
          _googleLogoAsset,
          width: 24,
          height: 24,
          errorBuilder: (context, error, stackTrace) {
            return const Text(
              'G',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4285F4),
              ),
            );
          },
        ),
        label: Text(context.l10n.ui('Continue with Google')),
      ),
    );
  }

  Widget _buildCreateAccountLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.l10n.ui("Don't have an account? "),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
        GestureDetector(
          onTap: _onCreateAccount,
          child: Text(
            context.l10n.ui('Create an account'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
