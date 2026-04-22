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
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingComplete;
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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

  static const _green = AppTheme.brandBlueBright;

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
      final isOnline = ref
          .read(connectivityStreamProvider)
          .maybeWhen(data: (v) => v, orElse: () => true);

      if (!mounted) return;
      setState(() {
        if (account != null) {
          final tierLabel = account.tier == 'cloudBorn' ? 'Cloud' : 'Local';
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

  /// Legacy fallback for accounts that exist locally but are missing
  /// a device-registry entry. This preserves offline sign-in after
  /// migrations or partial registry corruption.
  Future<bool> _tryLocalFallbackSignIn({
    required String email,
    required String password,
  }) async {
    try {
      final dao = ref.read(userDatabaseProvider).userProfileDao;
      final service = LocalAuthService(dao: dao);
      final profile = await service.signIn(email: email, password: password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOnboardingComplete, true);
      ref
          .read(auth_state.authStateProvider.notifier)
          .setLocalBornSession(profile: profile);
      ref.read(selectedProfileIdProvider.notifier).clear();
      if (mounted) {
        unawaited(context.router.replaceAll([const AppShellRoute()]));
      }
      return true;
    } on InvalidCredentialsException {
      return false;
    } catch (_) {
      return false;
    }
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
        // Local-born account on this device → argon2id verification.
        // Swap to this account's DB first so the argon2 hash is read
        // from the correct file — otherwise we verify against whatever
        // DB was previously active and cross-account data leaks in.
        activeDbFileName = account.dbFileName;
        ref.invalidate(userDatabaseProvider);

        final dao = ref.read(userDatabaseProvider).userProfileDao;
        final service = LocalAuthService(dao: dao);
        final profile = await service.signIn(email: email, password: password);

        final prefs = await SharedPreferences.getInstance();
        final session = SessionPersistenceService(
          prefs: prefs,
          registry: registry,
        );
        await session.setActiveAccount(account.accountId);
        await prefs.setBool(kOnboardingComplete, true);

        ref
            .read(auth_state.authStateProvider.notifier)
            .setLocalBornSession(profile: profile);
        ref.read(selectedProfileIdProvider.notifier).clear();
        if (mounted) {
          unawaited(context.router.replaceAll([const AppShellRoute()]));
        }
      } else if (account != null && account.tier == 'cloudBorn') {
        // Cloud-born account on this device → try Firebase or cached session
        final isOnline = await InternetConnectionChecker.instance.hasConnection;
        if (isOnline) {
          final authRepo = ref.read(authRepositoryProvider);
          await authRepo.signInWithEmail(email, password);
          if (mounted) await _navigateAfterSignIn();
        } else {
          // Offline — try cached Firebase session. Swap to this
          // account's DB before reading its profile so we never pull
          // a row from the previously active account's DB.
          final fbUser = FirebaseAuth.instance.currentUser;
          if (fbUser != null && fbUser.uid == account.firebaseUid) {
            activeDbFileName = account.dbFileName;
            ref.invalidate(userDatabaseProvider);

            final profile = await ref
                .read(userDatabaseProvider)
                .userProfileDao
                .findCloudBornByFirebaseUid(fbUser.uid);
            if (profile != null) {
              ref
                  .read(auth_state.authStateProvider.notifier)
                  .setCloudBornSession(profile: profile);
              if (mounted) await _navigateAfterSignIn();
            } else {
              _showError(
                "This account's local data is missing. "
                'Connect to the internet to restore it.',
              );
            }
          } else {
            _showError(
              'This is a cloud account. Connect to the internet to sign in.',
            );
          }
        }
      } else {
        // Not in registry — try local fallback first, then Firebase.
        final signedInLocally = await _tryLocalFallbackSignIn(
          email: email,
          password: password,
        );
        if (signedInLocally) return;

        // Not on this device → try Firebase (could be account from another device)
        final isOnline = await InternetConnectionChecker.instance.hasConnection;
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
    } catch (e) {
      if (mounted) _showError('Sign-in failed: $e');
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
      if (!mounted) return;

      final googleUser = FirebaseAuth.instance.currentUser;
      if (googleUser == null) return;

      // Epic 21.8: check 5-account cap for genuinely new accounts
      final registry = ref.read(deviceRegistryProvider);
      final existingEntry = await registry.findByFirebaseUid(googleUser.uid);
      if (existingEntry == null) {
        final accounts = await registry.getAllAccounts();
        if (accounts.length >= kMaxDeviceAccounts) {
          if (mounted) {
            _showError(
              'Maximum $kMaxDeviceAccounts accounts reached. '
              'Remove one to add another.',
            );
          }
          await FirebaseAuth.instance.signOut();
          return;
        }
      }

      // Epic 21.8: collision with local-born account
      final localMatch = await registry.findByEmail(googleUser.email ?? '');
      if (localMatch != null && localMatch.tier == 'localBorn') {
        if (mounted) {
          _showError(
            'An offline account with this email exists on this device. '
            'Use the Upgrade to Cloud option in Settings instead.',
          );
        }
        await FirebaseAuth.instance.signOut();
        return;
      }

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

    // Epic 21: route this Firebase user into the right per-account DB
    // BEFORE promoteToCloud writes any profile rows. Otherwise the
    // placeholder profile lands in whichever DB was previously active
    // and the new account inherits the prior account's learning data.
    final registry = ref.read(deviceRegistryProvider);
    final existingEntry = await registry.findByFirebaseUid(user.uid);
    final prefs = await SharedPreferences.getInstance();
    final session = SessionPersistenceService(prefs: prefs, registry: registry);

    if (existingEntry != null) {
      // Returning account on this device — swap to its DB file.
      if (activeDbFileName != existingEntry.dbFileName) {
        activeDbFileName = existingEntry.dbFileName;
        ref.invalidate(userDatabaseProvider);
      }
      await ref
          .read(auth_state.authStateProvider.notifier)
          .promoteToCloud(user);
      if (!mounted) return;
      await session.setActiveAccount(existingEntry.accountId);
    } else {
      // Account not on this device — could be brand-new, or an existing
      // cloud account signing in on a new device. Allocate a fresh DB file
      // and register the account either way; we decide where to route
      // after pulling from Firestore and seeing whether profiles exist.
      final accountId = const Uuid().v4();
      final dbFileName = 'user_acc_$accountId.db';
      activeDbFileName = dbFileName;
      ref.invalidate(userDatabaseProvider);

      await ref
          .read(auth_state.authStateProvider.notifier)
          .promoteToCloud(user);
      if (!mounted) return;

      await session.registerAccount(
        accountId: accountId,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
        tier: 'cloudBorn',
        firebaseUid: user.uid,
        dbFileName: dbFileName,
      );
    }

    // Sync profiles from Firestore into local DB before navigating.
    // Invalidate the sync engine so it picks up the just-swapped DB +
    // auth state, then pull synchronously so the next route decision
    // sees the real profile count rather than an empty local table.
    ref.invalidate(syncEngineProvider);
    final syncEngine = ref.read(syncEngineProvider);
    if (syncEngine != null) {
      await syncEngine.pullOnLaunch();
    }
    if (!mounted) return;

    // Decide onboarding vs app-shell by whether the cloud account has
    // any learner profiles. This is the single source of truth — local
    // data freshly pulled from Firestore — so new-device restores of
    // an existing cloud account land straight in the profile picker.
    var profileCount = await ref
        .read(userDatabaseProvider)
        .profileDao
        .countProfilesForAccount(1);

    if (profileCount == 0) {
      // If local is still empty, double-check cloud account-level profiles.
      // This avoids incorrectly routing returning cloud users into onboarding
      // when profile restore lagged behind the first pull attempt.
      final remoteProfiles = await ref
              .read(firestoreDataSourceProvider)
              ?.fetchLearnerProfiles() ??
          const <Map<String, dynamic>>[];

      if (remoteProfiles.isNotEmpty && syncEngine != null) {
        await syncEngine.pullOnLaunch();
        profileCount = await ref
            .read(userDatabaseProvider)
            .profileDao
            .countProfilesForAccount(1);
      }
    }

    if (profileCount == 0) {
      // Brand-new cloud account with no existing cloud profiles — run through
      // onboarding to create the first profile + pick tracks.
      if (!mounted) return;
      unawaited(context.router.replaceAll([const OnboardingRoute()]));
      return;
    }

    // If exactly one profile exists, select it immediately and re-pull
    // profile-scoped Firestore data (tracks/completions/etc) with the
    // correct profileId instead of the bootstrap default (0).
    final profiles = await ref
        .read(userDatabaseProvider)
        .profileDao
        .getProfilesByAccount(1);
    if (profiles.length == 1) {
      ref.read(selectedProfileIdProvider.notifier).select(profiles.first.id);
      ref.invalidate(syncEngineProvider);
      final selectedSyncEngine = ref.read(syncEngineProvider);
      if (selectedSyncEngine != null) {
        await selectedSyncEngine.pullOnLaunch();
      }
    } else {
      // Multiple profiles: user chooses in profile picker.
      ref.read(selectedProfileIdProvider.notifier).clear();
    }

    await prefs.setBool(kOnboardingComplete, true);
    if (!mounted) return;
    unawaited(context.router.replaceAll([const AppShellRoute()]));
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.brandCream,
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
                              color: AppTheme.brandInk,
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
                color: AppTheme.brandInk,
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
                color: AppTheme.brandInkMuted,
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
              color: AppTheme.brandInkMuted,
              size: 20,
            ),
          ),
          style: const TextStyle(color: AppTheme.brandInk),
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
                      ? AppTheme.brandGoldDeep
                      : AppTheme.brandInkMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _registryHint!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _registryHint!.startsWith('Found')
                          ? AppTheme.brandGoldDeep
                          : AppTheme.brandInkMuted,
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
              color: AppTheme.brandInkMuted,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.brandInkMuted,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          style: const TextStyle(color: AppTheme.brandInk),
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
            Expanded(child: Divider(color: AppTheme.brandOutline)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR CONTINUE WITH',
                style: TextStyle(
                  color: AppTheme.brandInkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppTheme.brandOutline)),
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
              style: TextStyle(color: AppTheme.brandInkMuted, fontSize: 14),
              children: [
                const TextSpan(text: "Don't have an account? "),
                TextSpan(
                  text: 'Get started',
                  style: const TextStyle(
                    color: AppTheme.brandBlueBright,
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
        color: AppTheme.brandInkMuted,
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
    const green = AppTheme.brandBlueBright;
    const greenDark = AppTheme.brandBlue;

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
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.white,
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
        color: AppTheme.brandCreamCard,
        border: Border.all(color: AppTheme.brandOutline),
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
                  color: AppTheme.brandBlueSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.g_mobiledata,
                  size: 22,
                  color: AppTheme.brandBlue,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Sign in with Google',
                style: TextStyle(
                  color: AppTheme.brandInk,
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
    const color = AppTheme.brandBlueBright;

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
