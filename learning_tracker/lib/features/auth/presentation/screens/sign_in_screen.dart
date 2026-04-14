import 'dart:async';
import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/auth/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart'
    as auth_state;
import 'package:learning_tracker/features/auth/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/validators/auth_validators.dart'
    as validators;
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingComplete;
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? _registryHint;
  Timer? _emailDebounce;

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
    _emailDebounce?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Epic 21.7: debounced live lookup against the device registry
  /// as the user types their email.
  void _onEmailChanged(String email) {
    _emailDebounce?.cancel();
    _emailDebounce = Timer(const Duration(milliseconds: 300), () async {
      final normalized = email.trim().toLowerCase();
      if (normalized.length < 5) {
        if (_registryHint != null) setState(() => _registryHint = null);
        return;
      }

      final registry = ref.read(deviceRegistryProvider);
      final account = await registry.findByEmail(normalized);
      final isOnline = ref.read(connectivityStreamProvider).maybeWhen(
            data: (v) => v,
            orElse: () => true,
          );

      if (!mounted) return;
      setState(() {
        if (account != null) {
          final tierLabel =
              account.tier == 'cloudBorn' ? 'Cloud' : 'Local';
          _registryHint = 'Found on this device ($tierLabel)';
        } else if (isOnline) {
          _registryHint = "Not on this device \u2014 we'll check the cloud";
        } else {
          _registryHint =
              'Not on this device (offline \u2014 only device accounts available)';
        }
      });
    });
  }

  String? _validateEmail(String? value) => validators.validateEmail(value);

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  /// Epic 21.7: Smart credential routing. Checks the device
  /// registry first to determine which backend handles sign-in,
  /// then falls back to Firebase for emails not on this device.
  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      // Step 1: check device registry for this email
      final registry = ref.read(deviceRegistryProvider);
      final account = await registry.findByEmail(email);

      if (account != null && account.tier == 'localBorn') {
        // Local-born account on this device → argon2id verification
        final dao = ref.read(userDatabaseProvider).userProfileDao;
        final service = LocalAuthService(dao: dao);
        final profile = await service.signIn(
          email: email,
          password: password,
        );
        ref
            .read(auth_state.authStateProvider.notifier)
            .setLocalBornSession(profile: profile);
        if (mounted) await _navigateAfterSignIn();
      } else if (account != null && account.tier == 'cloudBorn') {
        // Cloud-born account on this device → try Firebase or cached session
        final isOnline =
            await InternetConnectionChecker.instance.hasConnection;
        if (isOnline) {
          final authRepo = ref.read(authRepositoryProvider);
          await authRepo.signInWithEmail(email, password);
          if (mounted) await _navigateAfterSignIn();
        } else {
          // Offline — try cached Firebase session
          final fbUser = FirebaseAuth.instance.currentUser;
          if (fbUser != null && fbUser.uid == account.firebaseUid) {
            // Cached session still valid → resume instantly
            ref
                .read(auth_state.authStateProvider.notifier)
                .setCloudBornSession(
                  profile: (await ref
                      .read(userDatabaseProvider)
                      .userProfileDao
                      .findCloudBornByFirebaseUid(fbUser.uid))!,
                );
            if (mounted) await _navigateAfterSignIn();
          } else {
            _showError(
              'This is a cloud account. Connect to the internet to sign in.',
            );
          }
        }
      } else {
        // Not on this device → try Firebase (could be account from another device)
        final isOnline =
            await InternetConnectionChecker.instance.hasConnection;
        if (isOnline) {
          final authRepo = ref.read(authRepositoryProvider);
          await authRepo.signInWithEmail(email, password);
          if (mounted) await _navigateAfterSignIn();
        } else {
          _showError(
            "This email isn't on this device and we can't reach the cloud. "
            'Try again when online.',
          );
        }
      }
    } on InvalidCredentialsException {
      if (mounted) _showError('Incorrect password.');
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_mapAuthError(e.code));
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
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        // User cancelled — do nothing.
      } else if (mounted) {
        _showError('Google Sign-In failed. Please try again.');
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

    // Promote auth state so SyncEngine activates
    await ref.read(auth_state.authStateProvider.notifier).promoteToCloud(user);
    if (!mounted) return;

    // If onboarding was already completed on this device, go straight to app.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(kOnboardingComplete) ?? false) {
      if (!mounted) return;
      unawaited(context.router.replaceAll([const AppShellRoute()]));
      return;
    }

    final profileService = ref.read(userProfileServiceProvider);
    final existingMode = await profileService.getUserMode(user.uid);
    if (!mounted) return;

    if (existingMode != null) {
      final activationService = ref.read(curriculumActivationServiceProvider);
      final active = await activationService.getActiveCurricula();
      if (!mounted) return;
      if (active.isNotEmpty) {
        // Returning user with existing data — mark onboarding complete
        // so AuthGuard on AppShellRoute doesn't redirect back.
        await prefs.setBool(kOnboardingComplete, true);
        if (!mounted) return;
        unawaited(context.router.replaceAll([const AppShellRoute()]));
      } else {
        unawaited(context.router.replace(const OnboardingRoute()));
      }
    } else {
      unawaited(context.router.push(const OnboardingRoute()));
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
          onChanged: _onEmailChanged,
        ),
        // Epic 21.7: registry hint — shows where credentials
        // will be checked as the user types.
        if (_registryHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                Icon(
                  _registryHint!.startsWith('Found')
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 14,
                  color: _registryHint!.startsWith('Found')
                      ? const Color(0xFF4ADE80)
                      : Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _registryHint!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _registryHint!.startsWith('Found')
                          ? const Color(0xFF4ADE80)
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
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
                  text: 'Get started',
                  style: const TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      if (!_isLoading) {
                        context.router.replace(const OnboardingRoute());
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
