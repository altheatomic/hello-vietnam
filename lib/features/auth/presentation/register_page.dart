import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSignUp() {
    // TODO: Implement sign up logic
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    // Placeholder: go back to login after sign up
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created! Please login.')),
    );
    context.go(AppRoutes.login);
  }

  void _onGoogleSignIn() {
    // TODO: Implement Google Sign-In
  }

  void _onLogin() {
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
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
                      const SizedBox(height: 8),
                      _buildTitle(),
                      const SizedBox(height: 28),
                      _buildNameField(),
                      const SizedBox(height: 16),
                      _buildEmailField(),
                      const SizedBox(height: 16),
                      _buildPasswordField(),
                      const SizedBox(height: 16),
                      _buildConfirmPasswordField(),
                      const SizedBox(height: 28),
                      _buildSignUpButton(),
                      const SizedBox(height: 20),
                      _buildOrDivider(),
                      const SizedBox(height: 20),
                      _buildGoogleButton(),
                      const SizedBox(height: 28),
                      _buildLoginLink(),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Fixed back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: IconButton(
              onPressed: () => context.pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.7),
              ),
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
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
      children: [
        // White background + full image
        Container(
          width: double.infinity,
          height: 280 + statusBarHeight,
          color: Colors.white,
          padding: EdgeInsets.only(top: statusBarHeight),
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0.0, 0.7, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: Image.network(
              'https://clzyqllrxiuelegukanu.supabase.co/storage/v1/object/sign/Image%20for%20FE/Login/Signup1.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9hNDM4ZmU1My04MzcwLTQxMDAtOTlkOC1jMDhkMjI3NDQ1NmMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJJbWFnZSBmb3IgRkUvTG9naW4vU2lnbnVwMS5wbmciLCJpYXQiOjE3NzI2MjEyMzUsImV4cCI6MTgwNDE1NzIzNX0.az5cNFaAS8s0pQ-1U629rf5WSaL2AvqqV01kAsbEXcU',
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFB3E5FC)),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        const Text(
          'Sign Up to Explore',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
            height: 1.3,
          ),
        ),
        Text(
          'Amazing Trips',
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

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      decoration: _inputDecoration(
        hintText: 'Enter your name',
        prefixIcon: Icons.person_outline,
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: _inputDecoration(
        hintText: 'Enter your email',
        prefixIcon: Icons.mail_outline,
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: _inputDecoration(
        hintText: 'Enter your password',
        prefixIcon: Icons.lock_outline,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      decoration: _inputDecoration(
        hintText: 'Confirm password',
        prefixIcon: Icons.lock_outline,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(prefixIcon, color: Colors.grey.shade400),
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
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _onSignUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB3E5FC),
          foregroundColor: const Color(0xFF1A1A2E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: const Text('Sign up'),
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
            'Or login with',
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
          foregroundColor: const Color(0xFF1A1A2E),
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: Image.network(
          'https://clzyqllrxiuelegukanu.supabase.co/storage/v1/object/sign/Image%20for%20FE/Login/Google_Logo.svg.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9hNDM4ZmU1My04MzcwLTQxMDAtOTlkOC1jMDhkMjI3NDQ1NmMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJJbWFnZSBmb3IgRkUvTG9naW4vR29vZ2xlX0xvZ28uc3ZnLnBuZyIsImlhdCI6MTc3MjYwOTQ3MywiZXhwIjoxODA0MTQ1NDczfQ.chqQWTwgf4ZxTx6pJdUNjkLPiUCE7kqSfT51prRYg_g',
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
        label: const Text('Continue with Google'),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
        GestureDetector(
          onTap: _onLogin,
          child: const Text(
            'Login',
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
