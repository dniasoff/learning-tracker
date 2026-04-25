import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/auth/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/auth/domain/services/session_persistence_service.dart';
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
import 'package:uuid/uuid.dart';

@RoutePage()
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({
    super.key,
    this.prefilledName,
    this.prefilledEmail,
  });

  /// Pre-fills the name field when returning from a connectivity
  /// wait flow with the same draft values.
  final String? prefilledName;
  final String? prefilledEmail;

  @override
  ConsumerState<SignupScreen> createState() =>
      _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _offlineAcknowledged = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledName != null) {
      _nameController.text = widget.prefilledName!;
    }
    if (widget.prefilledEmail != null) {
      _emailController.text = widget.prefilledEmail!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) => validators.validateEmail(value);

  String? _validatePassword(String? value) =>
      validators.validatePassword(value);

  String? _validateDisplayName(String? value) =>
      validators.validateDisplayName(value);

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final displayName = _nameController.text.trim();

    // Epic 21.5: one-shot connectivity check at tap time decides
    // which backend handles the signup. The stream keeps the UI
    // honest (banner/warning); the one-shot prevents stale-stream
    // race conditions at execution time.
    final isOnline = await InternetConnectionChecker.instance.hasConnection;

    if (!isOnline) {
      // Offline path — local-born via argon2id.
      if (!_offlineAcknowledged) {
        _showError(
          'Please acknowledge the offline account warning before '
          'creating an offline account.',
        );
        return;
      }
      await _signUpLocal(email, password, displayName);
    } else {
      // Online path — cloud-born via Firebase.
      await _signUpCloud(email, password, displayName);
    }
  }

  Future<void> _signUpCloud(
    String email,
    String password,
    String displayName,
  ) async {
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signUp(email, password, displayName);
      await authRepo.sendEmailVerification();
      await authRepo.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification email sent. Verify your email, then sign in.',
            ),
          ),
        );
        unawaited(context.router.replace(const SignInRoute()));
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed' && mounted) {
        // Race condition: one-shot said online but Firebase call
        // failed. Offer graceful fallback to offline account.
        _showFallbackDialog(email, password, displayName);
        return;
      }
      if (mounted) _showError(_mapAuthError(e.code));
    } on DuplicateEmailException {
      if (mounted) _showError('An account already exists with this email.');
    } on InvalidInputException catch (e) {
      if (mounted) _showError(e.reason);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpLocal(
    String email,
    String password,
    String displayName,
  ) async {
    setState(() => _isLoading = true);
    try {
      // Epic 21: swap to a fresh per-account DB before writing the
      // local-born profile so each account's data lives in its own
      // file and the registry entry points at the right DB.
      final accountId = const Uuid().v4();
      final dbFileName = 'user_acc_$accountId.db';
      activeDbFileName = dbFileName;
      ref.invalidate(userDatabaseProvider);

      final dao = ref.read(userDatabaseProvider).userProfileDao;
      final service = LocalAuthService(dao: dao);
      final profile = await service.signUp(
        email: email,
        password: password,
        displayName: displayName,
        userMode: 'adult',
      );

      final prefs = await SharedPreferences.getInstance();
      final session = SessionPersistenceService(
        prefs: prefs,
        registry: ref.read(deviceRegistryProvider),
      );
      await session.registerAccount(
        accountId: accountId,
        email: email,
        displayName: displayName,
        tier: 'localBorn',
        dbFileName: dbFileName,
      );

      ref
          .read(auth_state.authStateProvider.notifier)
          .setLocalBornSession(profile: profile);
      if (mounted) {
        unawaited(context.router.push(const OnboardingRoute()));
      }
    } on DuplicateEmailException {
      if (mounted) {
        _showError(
          'An offline account already exists on this device with that email.',
        );
      }
    } on InvalidInputException catch (e) {
      if (mounted) _showError(e.reason);
    } catch (e) {
      if (mounted) _showError('Signup failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shown when the one-shot said "online" but Firebase threw
  /// network-request-failed mid-call. Offers to create an offline
  /// account instead or retry.
  void _showFallbackDialog(String email, String password, String displayName) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connection lost'),
        content: const Text(
          'The internet connection dropped during signup. '
          'Would you like to create an offline account instead?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _signUpCloud(email, password, displayName);
            },
            child: const Text('Try Again'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _offlineAcknowledged = true);
              _signUpLocal(email, password, displayName);
            },
            child: const Text('Create Offline Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithGoogle();
      if (!mounted) return;

      final googleUser = ref.read(firebaseAuthProvider).currentUser;
      if (googleUser == null) return;

      // Epic 21.6: check 5-account cap before adding
      final registry = ref.read(deviceRegistryProvider);
      final accounts = await registry.getAllAccounts();
      // Only count if this is genuinely a NEW account on this device
      final existingEntry = await registry.findByFirebaseUid(googleUser.uid);
      if (existingEntry == null && accounts.length >= kMaxDeviceAccounts) {
        if (mounted) {
          _showError(
            'Maximum $kMaxDeviceAccounts accounts reached. '
            'Remove one to add another.',
          );
        }
        // Sign out the just-signed-in Google user to avoid orphan state
        await FirebaseAuth.instance.signOut();
        return;
      }

      // Epic 21.6: check collision with local-born account
      final localMatch = await registry.findByEmail(googleUser.email ?? '');
      if (localMatch != null && localMatch.tier == 'localBorn') {
        // Google returned an email matching a local-born account on
        // this device — route to collision/upgrade flow instead of
        // silently merging.
        if (mounted) {
          _showError(
            'An offline account with this email exists on this device. '
            'Use the Upgrade to Cloud option in Settings instead.',
          );
        }
        await FirebaseAuth.instance.signOut();
        return;
      }

      // Epic 21: register a per-account DB for brand-new Google
      // accounts. Returning-user flows (existingEntry != null) keep
      // the existing DB file — the registry row already points at it.
      if (existingEntry == null) {
        final accountId = const Uuid().v4();
        final dbFileName = 'user_acc_$accountId.db';
        activeDbFileName = dbFileName;
        ref.invalidate(userDatabaseProvider);

        await ref
            .read(auth_state.authStateProvider.notifier)
            .promoteToCloud(googleUser);

        final prefsForReg = await SharedPreferences.getInstance();
        final session = SessionPersistenceService(
          prefs: prefsForReg,
          registry: registry,
        );
        await session.registerAccount(
          accountId: accountId,
          email: googleUser.email ?? '',
          displayName: googleUser.displayName ?? '',
          tier: 'cloudBorn',
          firebaseUid: googleUser.uid,
          dbFileName: dbFileName,
        );
      } else {
        // Existing account on this device — swap to its DB and
        // refresh lastUsedAt so session persistence stays coherent.
        activeDbFileName = existingEntry.dbFileName;
        ref.invalidate(userDatabaseProvider);
        await ref
            .read(auth_state.authStateProvider.notifier)
            .promoteToCloud(googleUser);
        final prefsForReg = await SharedPreferences.getInstance();
        final session = SessionPersistenceService(
          prefs: prefsForReg,
          registry: registry,
        );
        await session.setActiveAccount(existingEntry.accountId);
      }
      if (!mounted) return;

      // If onboarding was already completed on this device, skip it.
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(kOnboardingComplete) ?? false) {
        if (!mounted) return;
        unawaited(context.router.replaceAll([const AppShellRoute()]));
        return;
      }

      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user != null && mounted) {
        final profileService = ref.read(userProfileServiceProvider);
        final existingMode = await profileService.getUserMode(user.uid);
        if (mounted) {
          if (existingMode != null) {
            final activationService = ref.read(
              curriculumActivationServiceProvider,
            );
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

  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Account creation failed. Please try again.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.brandCoralDeep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connectivity = ref.watch(connectivityStreamProvider);
    final isOnline = connectivity.maybeWhen(data: (v) => v, orElse: () => true);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 28,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -50,
                          right: -58,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE9EAF2),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
                          decoration: BoxDecoration(
                            color: AppTheme.brandCreamCard,
                            borderRadius: BorderRadius.circular(34),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Create Account',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Start your journey today!',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: AppTheme.brandInkMuted,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildAccountModeCard(theme: theme, isOnline: isOnline),
                                const SizedBox(height: 22),
                                if (isOnline) ...[
                                  OutlinedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : _signUpWithGoogle,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.brandInk,
                                      side: const BorderSide(
                                        color: Color(0xFFC8CCD8),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.g_mobiledata_rounded),
                                          SizedBox(width: 8),
                                          Text(
                                            'Sign Up with Google',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      const Expanded(child: Divider()),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        child: Text(
                                          'OR',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: AppTheme.brandInkMuted,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.8,
                                              ),
                                        ),
                                      ),
                                      const Expanded(child: Divider()),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                ],
                                if (!isOnline) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.brandCoralSoft.withValues(
                                        alpha: 0.45,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _offlineAcknowledged,
                                          onChanged: _isLoading
                                              ? null
                                              : (value) => setState(
                                                  () => _offlineAcknowledged =
                                                      value ?? false,
                                                ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Offline mode: account stays only on this device.',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                _buildLabel('Display Name'),
                                const SizedBox(height: 8),
                                _buildAuthField(
                                  controller: _nameController,
                                  hintText: 'Scholar Name',
                                  suffixIcon: const Icon(
                                    Icons.face_outlined,
                                    color: AppTheme.brandInkMuted,
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: _validateDisplayName,
                                ),
                                const SizedBox(height: 16),
                                _buildLabel('Email Address'),
                                const SizedBox(height: 8),
                                _buildAuthField(
                                  controller: _emailController,
                                  hintText: 'you@quest.com',
                                  suffixIcon: const Icon(
                                    Icons.email_rounded,
                                    color: AppTheme.brandInkMuted,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  validator: _validateEmail,
                                ),
                                const SizedBox(height: 16),
                                _buildLabel('Create Password'),
                                const SizedBox(height: 8),
                                _buildAuthField(
                                  controller: _passwordController,
                                  hintText: '........',
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  validator: _validatePassword,
                                  onFieldSubmitted: (_) => _signUpWithEmail(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.lock_rounded
                                          : Icons.visibility_rounded,
                                      color: AppTheme.brandInkMuted,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 58,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppTheme.brandBlue,
                                          AppTheme.brandBlueBright,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.brandBlueBright
                                              .withValues(alpha: 0.32),
                                          blurRadius: 18,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: FilledButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _signUpWithEmail,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppTheme.transparent,
                                        shadowColor: AppTheme.transparent,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppTheme.brandCreamCard,
                                              ),
                                            )
                                          : Text(
                                              isOnline
                                                  ? 'Sign Up'
                                                  : 'Create Offline Account',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Center(
                                  child: RichText(
                                    text: TextSpan(
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: AppTheme.brandInkMuted,
                                          ),
                                      children: [
                                        const TextSpan(
                                          text: 'Already exploring? ',
                                        ),
                                        TextSpan(
                                          text: 'Log In',
                                          style: const TextStyle(
                                            color: AppTheme.brandBlue,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              if (!_isLoading) {
                                                context.router.replace(
                                                  const SignInRoute(),
                                                );
                                              }
                                            },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const SizedBox(height: 8),
                  Text(
                    '© 2024 MITZVAH QUEST • THE LEARNING PLAYGROUND',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.brandInkMuted,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.brandInk,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildAccountModeCard({
    required ThemeData theme,
    required bool isOnline,
  }) {
    if (isOnline) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.brandBlueBright.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.brandBlueBright.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_done_rounded, color: AppTheme.brandBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cloud account: your data is backed up and can sync across devices.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.brandInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.brandCoralSoft.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.brandCoralDeep.withValues(alpha: 0.55)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.brandCoralDeep),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Local account only: no cloud backup and no device sync.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.brandInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.brandCoralSoft.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.brandCoralDeep.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.dangerous_rounded,
                color: AppTheme.brandCoralDeep,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No cloud backup or device sync. Your data stays only on this device.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.brandInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthField({
    required TextEditingController controller,
    required String hintText,
    required Widget suffixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      enabled: !_isLoading,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: AppTheme.brandInkMuted,
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF0F1F6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppTheme.brandBlueBright),
        ),
      ),
    );
  }
}
