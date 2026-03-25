import 'dart:async';
import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/validators/auth_validators.dart'
    as validators;
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';

@RoutePage()
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late final AnimationController _entranceController;
  late final AnimationController _pulseController;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _formSlide;
  late final Animation<double> _formFade;
  late final Animation<double> _bottomFade;

  static const _green = Color(0xFF4ADE80);

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );
    _formSlide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _formFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
    );
    _bottomFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) => validators.validateEmail(value);

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        await _navigateAfterSignIn();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showError(_mapAuthError(e.code));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email address first.');
      return;
    }
    final emailError = validators.validateEmail(email);
    if (emailError != null) {
      _showError(emailError);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Check your inbox.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showError(_mapAuthError(e.code));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithGoogle();
      if (mounted) {
        await _navigateAfterSignIn();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showError(_mapAuthError(e.code));
      }
    } catch (e) {
      if (mounted) {
        _showError('Google Sign-In failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateAfterSignIn() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null || !mounted) return;

    final profileService = ref.read(userProfileServiceProvider);
    final existingMode = await profileService.getUserMode(user.uid);
    if (!mounted) return;

    if (existingMode != null) {
      final activationService = ref.read(curriculumActivationServiceProvider);
      final active = await activationService.getActiveCurricula();
      if (!mounted) return;
      if (active.isNotEmpty) {
        unawaited(context.router.replaceAll([const AppShellRoute()]));
      } else {
        unawaited(context.router.replace(const OnboardingRoute()));
      }
    } else {
      unawaited(context.router.push(const ModeSelectionRoute()));
    }
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Animated background particles
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _SignInParticlePainter(progress: _pulseController.value),
            ),
          ),

          // Top-right gradient orb
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final pulse = _pulseController.value;
              return Positioned(
                top: -100,
                right: -60,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _green.withValues(alpha: 0.08 + pulse * 0.04),
                        _green.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Bottom-left gradient orb
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _green.withValues(alpha: 0.05),
                    _green.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: AnimatedBuilder(
              animation: _entranceController,
              builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),

                      // Back button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FadeTransition(
                          opacity: _logoFade,
                          child: IconButton(
                            onPressed: () => context.router.maybePop(),
                            icon: const Icon(
                              Icons.arrow_back_ios,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Animated logo
                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: _buildLogoSection(),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Form fields with slide animation
                      Transform.translate(
                        offset: Offset(0, _formSlide.value),
                        child: Opacity(
                          opacity: _formFade.value,
                          child: _buildFormSection(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bottom section
                      FadeTransition(
                        opacity: _bottomFade,
                        child: _buildBottomSection(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = _pulseController.value;
        return Column(
          children: [
            // Glowing icon container
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _green.withValues(alpha: 0.15),
                    _green.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: _green.withValues(alpha: 0.2 + pulse * 0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.1 + pulse * 0.08),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                size: 32,
                color: _green,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome Back',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to continue your learning journey',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email field
        _buildLabel('Email Address'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            hintText: 'name@example.com',
            prefixIcon: Icon(
              Icons.email_outlined,
              color: Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
          ),
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: _validateEmail,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 20),

        // Password field
        _buildLabel('Password'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            hintText: 'Enter your password',
            prefixIcon: Icon(
              Icons.lock_outline,
              color: Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          style: const TextStyle(color: Colors.white),
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          validator: _validatePassword,
          enabled: !_isLoading,
          onFieldSubmitted: (_) => _signInWithEmail(),
        ),
        const SizedBox(height: 4),

        // Forgot password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : _sendPasswordReset,
            style: TextButton.styleFrom(
              foregroundColor: _green,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: const Text(
              'Forgot password?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Sign In button
        _SignInGlowButton(
          onTap: _isLoading ? null : _signInWithEmail,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        // OR divider
        Row(
          children: [
            Expanded(
              child: Divider(color: Colors.white.withValues(alpha: 0.08)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR CONTINUE WITH',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(
              child: Divider(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Google sign in button
        _GoogleSignInButton(onTap: _isLoading ? null : _signInWithGoogle),
        const SizedBox(height: 32),

        // Create account link
        Center(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              children: [
                const TextSpan(text: "Don't have an account? "),
                TextSpan(
                  text: 'Create one',
                  style: const TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      if (!_isLoading) {
                        context.router.replace(const AccountCreationRoute());
                      }
                    },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// -- Glowing sign-in button --

class _SignInGlowButton extends StatefulWidget {
  const _SignInGlowButton({required this.onTap, required this.isLoading});

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  State<_SignInGlowButton> createState() => _SignInGlowButtonState();
}

class _SignInGlowButtonState extends State<_SignInGlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF4ADE80);
    const greenDark = Color(0xFF22C55E);

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, _) {
        final glow = 0.2 + _glowController.value * 0.25;
        return Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(colors: [greenDark, green]),
            boxShadow: [
              BoxShadow(
                color: green.withValues(alpha: glow),
                blurRadius: 20,
                offset: const Offset(0, 6),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: green.withValues(alpha: glow * 0.3),
                blurRadius: 36,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(28),
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// -- Google sign-in button --

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.g_mobiledata,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Sign in with Google',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Background particle painter --

class _SignInParticlePainter extends CustomPainter {
  _SignInParticlePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(77);
    const color = Color(0xFF4ADE80);

    for (var i = 0; i < 20; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final phase = random.nextDouble() * 2 * pi;

      final x = baseX + sin(progress * 2 * pi + phase) * 12;
      final y = baseY + cos(progress * 2 * pi * 0.7 + phase) * 10;

      final radius = 0.8 + random.nextDouble() * 1.5;
      final alpha =
          (0.04 + random.nextDouble() * 0.08) *
          (0.5 + sin(progress * 2 * pi + phase) * 0.5);

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_SignInParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
