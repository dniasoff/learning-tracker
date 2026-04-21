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
class AccountCreationScreen extends ConsumerStatefulWidget {
  const AccountCreationScreen({
    super.key,
    this.prefilledName,
    this.prefilledEmail,
  });

  /// Pre-fills the name field when the user came from the local
  /// signup screen via "Wait for Internet" reconnection.
  final String? prefilledName;
  final String? prefilledEmail;

  @override
  ConsumerState<AccountCreationScreen> createState() =>
      _AccountCreationScreenState();
}

class _AccountCreationScreenState extends ConsumerState<AccountCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
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
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) => validators.validateEmail(value);

  String? _validatePassword(String? value) =>
      validators.validatePassword(value);

  String? _validateDisplayName(String? value) =>
      validators.validateDisplayName(value);

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  double _passwordStrength(String password) {
    if (password.isEmpty) return 0;
    var score = 0.0;
    if (password.length >= 6) score += 0.25;
    if (password.length >= 8) score += 0.25;
    if (RegExp('[A-Z]').hasMatch(password)) score += 0.15;
    if (RegExp('[0-9]').hasMatch(password)) score += 0.15;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score += 0.2;
    return score.clamp(0.0, 1.0);
  }

  String _passwordStrengthLabel(double strength) {
    if (strength <= 0) return '';
    if (strength < 0.4) return 'WEAK';
    if (strength < 0.7) return 'FAIR';
    return 'GOOD';
  }

  Color _passwordStrengthColor(double strength) {
    if (strength < 0.4) return AppTheme.brandCoralDeep;
    if (strength < 0.7) return AppTheme.brandGoldDeep;
    return AppTheme.brandBlueBright;
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showError('Please agree to the Terms of Service and Privacy Policy.');
      return;
    }

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
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user != null) {
        // Epic 21: route the new user's profile into a per-account
        // DB file and register the account so sign-out can find it.
        final accountId = const Uuid().v4();
        final dbFileName = 'user_acc_$accountId.db';
        activeDbFileName = dbFileName;
        ref.invalidate(userDatabaseProvider);

        await ref
            .read(auth_state.authStateProvider.notifier)
            .promoteToCloud(user);

        final prefs = await SharedPreferences.getInstance();
        final session = SessionPersistenceService(
          prefs: prefs,
          registry: ref.read(deviceRegistryProvider),
        );
        await session.registerAccount(
          accountId: accountId,
          email: email,
          displayName: displayName,
          tier: 'cloudBorn',
          firebaseUid: user.uid,
          dbFileName: dbFileName,
        );
      }
      if (mounted) {
        unawaited(context.router.push(const OnboardingRoute()));
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strength = _passwordStrength(_passwordController.text);

    // Epic 21.5: watch connectivity to toggle the offline warning
    // block and Google button visibility in real time.
    final connectivity = ref.watch(connectivityStreamProvider);
    final isOnline = connectivity.maybeWhen(data: (v) => v, orElse: () => true);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                // Back button and title
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.router.maybePop(),
                      icon: const Icon(Icons.arrow_back_ios, size: 20),
                      style: IconButton.styleFrom(
                        foregroundColor: AppTheme.brandInk,
                      ),
                    ),
                    Text(
                      'Create Account',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.brandInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Create Account',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppTheme.brandInk,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Join thousands learning Torah daily',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.brandInkMuted,
                  ),
                ),
                const SizedBox(height: 20),

                // Epic 21.5: offline warning block — shown only
                // when the device is offline. Replaces the old
                // redirect to LocalSignupScreen.
                if (!isOnline) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.brandCoralSoft.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.brandCoral.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.cloud_off,
                              color: AppTheme.brandCoral,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "You're offline",
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppTheme.brandCoralDeep,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This account will be stored only on this device:\n'
                          '  \u2022 No cloud backup\n'
                          '  \u2022 No multi-device sync\n'
                          '  \u2022 Forget your password = account lost\n\n'
                          'You can upgrade to cloud later from Settings.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.brandInkMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _offlineAcknowledged,
                                onChanged: _isLoading
                                    ? null
                                    : (v) => setState(
                                        () => _offlineAcknowledged = v ?? false,
                                      ),
                                side: const BorderSide(
                                  color: AppTheme.brandCoral,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'I understand — no backup, no recovery',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.brandInkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Full Name
                _buildLabel('Full Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Enter your full name',
                  ),
                  style: const TextStyle(color: AppTheme.brandInk),
                  textInputAction: TextInputAction.next,
                  validator: _validateDisplayName,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 20),

                // Email
                _buildLabel('Email Address'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: 'name@example.com',
                  ),
                  style: const TextStyle(color: AppTheme.brandInk),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 20),

                // Create Password
                _buildLabel('Create Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    hintText: 'Min. 8 characters',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.brandInkMuted,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  style: const TextStyle(color: AppTheme.brandInk),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  validator: _validatePassword,
                  enabled: !_isLoading,
                  onChanged: (_) => setState(() {}),
                ),
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StrengthBar(
                          active: strength >= 0.25,
                          color: _passwordStrengthColor(strength),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _StrengthBar(
                          active: strength >= 0.5,
                          color: _passwordStrengthColor(strength),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _StrengthBar(
                          active: strength >= 0.7,
                          color: _passwordStrengthColor(strength),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _StrengthBar(
                          active: strength >= 0.9,
                          color: _passwordStrengthColor(strength),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _passwordStrengthLabel(strength),
                        style: TextStyle(
                          color: _passwordStrengthColor(strength),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // Confirm Password
                _buildLabel('Confirm Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    hintText: 'Repeat password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.brandInkMuted,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  style: const TextStyle(color: AppTheme.brandInk),
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  validator: _validateConfirmPassword,
                  enabled: !_isLoading,
                  onFieldSubmitted: (_) => _signUpWithEmail(),
                ),
                const SizedBox(height: 20),

                // Terms checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        onChanged: _isLoading
                            ? null
                            : (v) =>
                                  setState(() => _agreedToTerms = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: AppTheme.brandInkMuted,
                            fontSize: 13,
                          ),
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: const TextStyle(
                                color: AppTheme.brandBlueBright,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()..onTap = () {},
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
                                color: AppTheme.brandBlueBright,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()..onTap = () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Create Account button — text adapts to connectivity
                FilledButton(
                  onPressed: _isLoading ? null : _signUpWithEmail,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          isOnline
                              ? 'Create Account'
                              : 'Create Offline Account',
                        ),
                ),

                // Google Sign-In section — only shown when online
                if (isOnline) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppTheme.brandOutline)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR SIGN UP WITH',
                          style: TextStyle(
                            color: AppTheme.brandInkMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppTheme.brandOutline)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signUpWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 24),
                    label: const Text('Sign up with Google'),
                  ),
                ],
                const SizedBox(height: 32),

                // Sign in link
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: AppTheme.brandInkMuted,
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Sign In',
                          style: const TextStyle(
                            color: AppTheme.brandBlueBright,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              if (!_isLoading) {
                                context.router.replace(const SignInRoute());
                              }
                            },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppTheme.brandInkMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.active, required this.color});
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: active ? color : AppTheme.brandOutline.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
