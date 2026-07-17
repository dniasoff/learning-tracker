import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/firebase_error_code.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/features/account/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/account/domain/services/pending_local_signup.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/onboarding/onboarding.dart'
    show kOnboardingComplete;
import 'package:learning_tracker/features/onboarding/onboarding.dart'
    as validators
    show validateDisplayName, validateEmail, validatePassword;
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

@RoutePage()
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key, this.prefilledName, this.prefilledEmail});

  /// Pre-fills the name field when returning from a connectivity
  /// wait flow with the same draft values.
  final String? prefilledName;
  final String? prefilledEmail;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

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

  String? _validateEmail(String? value, AppLocalizations l10n) =>
      validators.validateEmail(value, l10n);

  String? _validatePassword(String? value, AppLocalizations l10n) =>
      validators.validatePassword(value, l10n);

  String? _validateDisplayName(String? value, AppLocalizations l10n) =>
      validators.validateDisplayName(value, l10n);

  /// Cloud sign-up handler — reached only from the ONLINE form (the offline
  /// branch shows an explicit "Create offline account" button that calls
  /// [_createOfflineAccount] directly, with no email/password).
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
      // Race: the online form was showing but connectivity dropped between
      // render and tap. Fall back to a credential-less offline account; the
      // typed email/password are discarded (an offline account has neither).
      await _createOfflineAccount();
    } else {
      await _signUpCloud(email, password, displayName);
    }
  }

  /// Creates a credential-less, device-local account: no email, no password,
  /// no account display name. An internal synthetic email/password are
  /// generated purely so the existing local-account plumbing (registry keying,
  /// argon2 hash column, restore-by-email) keeps working — they are never shown
  /// to or entered by the user. Onboarding goes straight to profile creation;
  /// the account is re-entered from the Account Picker, and can be backed up
  /// later via Upgrade to Cloud.
  Future<void> _createOfflineAccount() async {
    final id = const Uuid().v4();
    final syntheticEmail =
        'offline_${id.replaceAll('-', '').substring(0, 12)}@offline.local';
    final syntheticPassword = const Uuid().v4();
    await _signUpLocal(syntheticEmail, syntheticPassword, '');
  }

  /// Forces an immediate connectivity re-probe (the stream otherwise self-probes
  /// every few seconds while offline).
  void _retryConnection() {
    ref.invalidate(connectivityStreamProvider);
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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.signUpVerificationEmailSent)),
        );
        unawaited(context.router.replace(const SignInRoute()));
      }
    } on DuplicateEmailException {
      if (mounted)
        _showError(AppLocalizations.of(context)!.signUpEmailAlreadyExists);
    } on InvalidInputException catch (e) {
      if (mounted) _showError(_mapInvalidInputCode(e.code));
    } catch (e) {
      final code = extractFirebaseCode(e);
      if (code == 'network-request-failed' && mounted) {
        // Race condition: one-shot said online but Firebase call
        // failed. Offer graceful fallback to offline account.
        _showFallbackDialog(email, password, displayName);
        return;
      }
      if (mounted) {
        _showError(
          code != null
              ? _mapAuthError(code)
              : AppLocalizations.of(context)!.signUpErrGeneric,
        );
      }
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
    final normalized = email.trim().toLowerCase();
    final accountId = const Uuid().v4();
    final dbFileName = 'user_acc_$accountId.db';
    var reservedEmail = false;
    var switchedDb = false;

    Future<void> recover(String databasesPath) async {
      final prefs = await SharedPreferences.getInstance();
      if (reservedEmail) {
        await PendingLocalSignupStore.releaseEmail(prefs, normalized);
      }
      await PendingLocalSignupStore.clearPayload(prefs);
      if (switchedDb) {
        PendingLocalSignupStore.deleteOrphanDbFile(databasesPath, dbFileName);
        ref
            .read(accountDbFileNameProvider.notifier)
            .setFileName('learning_tracker');
        ref.invalidate(userDatabaseProvider);
      }
    }

    try {
      final registry = ref.read(deviceRegistryProvider);
      if (await registry.findByEmail(normalized) != null) {
        if (mounted) {
          _showError(AppLocalizations.of(context)!.signUpDeviceEmailExists);
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final reserved = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        normalized,
      );
      if (!reserved) {
        if (mounted) {
          _showError(AppLocalizations.of(context)!.signUpOfflineInProgress);
        }
        return;
      }
      reservedEmail = true;

      ref.read(accountDbFileNameProvider.notifier).setFileName(dbFileName);
      ref.invalidate(userDatabaseProvider);
      switchedDb = true;

      final dao = ref.read(userDatabaseProvider).userProfileDao;
      final service = LocalAuthService(dao: dao);
      final profile = await service.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );

      await PendingLocalSignupStore.writePayload(
        prefs,
        PendingLocalRegistration(
          accountId: accountId,
          dbFileName: dbFileName,
          email: normalized,
          displayName: displayName,
        ),
      );

      ref
          .read(authStateProvider.notifier)
          .setLocalBornSession(profile: profile);

      // Clear any cached Firebase user so offline local sessions are never
      // mistaken for cloud sign-in (downstream Firestore awaits would stall).
      // On emulators / devices without Google Play Services this can throw
      // PlatformException(clearCredentialStateAsync…).  The local account was
      // already created successfully, so a signOut failure must NOT roll back
      // the signup — swallow and log it.
      try {
        await ref.read(authRepositoryProvider).signOut();
      } catch (e) {
        // Best-effort cleanup — not fatal for the local signup path.
        AppLogger.instance.warning(
          event: 'sign_up_local_sign_out_failed',
          exception: e,
        );
      }

      if (!mounted) return;
      final router = context.router;
      final docs = await getApplicationDocumentsDirectory();
      if (!mounted) return;
      unawaited(
        router.push(const OnboardingRoute()).then((_) async {
          if (!mounted) return;
          await PendingLocalSignupStore.rollbackIfIncomplete(
            ref: ref,
            databasesPath: docs.path,
          );
        }),
      );
    } on DuplicateEmailException {
      final docs = await getApplicationDocumentsDirectory();
      await recover(docs.path);
      if (mounted) {
        _showError(AppLocalizations.of(context)!.signUpOfflineEmailExists);
      }
    } on InvalidInputException catch (e) {
      final docs = await getApplicationDocumentsDirectory();
      await recover(docs.path);
      if (mounted) _showError(_mapInvalidInputCode(e.code));
    } catch (e) {
      final docs = await getApplicationDocumentsDirectory();
      await recover(docs.path);
      // AUD-account-24: do not interpolate the raw exception into the
      // user-facing message (untranslated + leaks implementation detail).
      // Log it for diagnostics and show the existing localized generic
      // fallback instead — mirrors the cloud-signup path's own fallback for
      // an unmapped Firebase error code (see _mapAuthError's default arm).
      AppLogger.instance.warning(event: 'sign_up_local_failed', exception: e);
      if (mounted) {
        _showError(AppLocalizations.of(context)!.signUpErrGeneric);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shown when the one-shot said "online" but Firebase threw
  /// network-request-failed mid-call. Offers to create an offline
  /// account instead or retry.
  void _showFallbackDialog(String email, String password, String displayName) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.connectionLostTitle),
        content: Text(l10n.signUpFallbackBody),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _signUpCloud(email, password, displayName);
            },
            child: Text(l10n.tryAgainButton),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Offline accounts are credential-less; discard the typed
              // email/password and create a device-local account.
              _createOfflineAccount();
            },
            child: Text(l10n.createOfflineAccount),
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

      final googleUser = ref.read(authRepositoryProvider).currentUser;
      if (googleUser == null) return;

      // Epic 21.6: check 5-account cap before adding
      final registry = ref.read(deviceRegistryProvider);
      final accounts = await registry.getAllAccounts();
      // Only count if this is genuinely a NEW account on this device
      final existingEntry = await registry.findByFirebaseUid(googleUser.uid);
      if (existingEntry == null && accounts.length >= kMaxDeviceAccounts) {
        if (mounted) {
          _showError(
            AppLocalizations.of(
              context,
            )!.authMaxDeviceAccounts(kMaxDeviceAccounts),
          );
        }
        // Sign out the just-signed-in Google user to avoid orphan state
        await ref.read(authRepositoryProvider).signOut();
        return;
      }

      // Epic 21.6: check collision with local-born account
      final localMatch = await registry.findByEmail(googleUser.email ?? '');
      if (localMatch != null && localMatch.accountTier.isLocal) {
        // Google returned an email matching a local-born account on
        // this device — route to collision/upgrade flow instead of
        // silently merging.
        if (mounted) {
          _showError(AppLocalizations.of(context)!.authOfflineUseUpgrade);
        }
        await ref.read(authRepositoryProvider).signOut();
        return;
      }

      // Epic 21: register a per-account DB for brand-new Google
      // accounts. Returning-user flows (existingEntry != null) keep
      // the existing DB file — the registry row already points at it.
      if (existingEntry == null) {
        final accountId = const Uuid().v4();
        final dbFileName = 'user_acc_$accountId.db';
        ref.read(accountDbFileNameProvider.notifier).setFileName(dbFileName);
        ref.invalidate(userDatabaseProvider);

        await ref
            .read(authStateProvider.notifier)
            .setCloudBornSessionFromFirebaseUser(googleUser);

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
        ref
            .read(accountDbFileNameProvider.notifier)
            .setFileName(existingEntry.dbFileName);
        ref.invalidate(userDatabaseProvider);
        await ref
            .read(authStateProvider.notifier)
            .setCloudBornSessionFromFirebaseUser(googleUser);
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

      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null && mounted) {
        // Check if this is a returning user (account row already exists).
        final dao = ref.read(userDatabaseProvider).userProfileDao;
        final existingAccount = await dao.getUserProfileByFirebaseUid(user.uid);
        if (mounted) {
          if (existingAccount != null) {
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
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        // User cancelled — do nothing.
      } else if (mounted) {
        _showError(AppLocalizations.of(context)!.authGoogleSignInFailed);
      }
    } catch (e) {
      final code = extractFirebaseCode(e);
      if (mounted) {
        _showError(
          code != null
              ? _mapAuthError(code)
              : AppLocalizations.of(context)!.authGoogleSignInFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(String code) {
    final l10n = AppLocalizations.of(context)!;
    switch (code) {
      case 'email-already-in-use':
        return l10n.signUpEmailAlreadyExists;
      case 'weak-password':
        return l10n.signUpErrWeakPassword;
      case 'invalid-email':
        return l10n.authErrInvalidEmail;
      case 'network-request-failed':
        return l10n.authErrNetwork;
      // AUD-account-12: a user whose email already has a password-based
      // Firebase account taps "Sign up with Google" using that same
      // address. Without this case the generic fallback gives zero
      // guidance to use the existing password.
      case 'account-exists-with-different-credential':
        return l10n.authErrExistingPasswordAccount;
      default:
        return l10n.signUpErrGeneric;
    }
  }

  /// Resolves a [LocalAuthService]-thrown [InvalidInputException.code] to a
  /// localized message (EH-5) — [InvalidInputException.reason] is
  /// English-only and log-safe, never shown to users directly.
  String _mapInvalidInputCode(InvalidInputCode code) {
    final l10n = AppLocalizations.of(context)!;
    return switch (code) {
      InvalidInputCode.invalidEmail => l10n.authErrInvalidEmail,
      InvalidInputCode.passwordTooShort => l10n.signUpErrWeakPassword,
      InvalidInputCode.displayNameRequired => l10n.signUpErrGeneric,
    };
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
    final l10n = AppLocalizations.of(context)!;
    final connectivity = ref.watch(connectivityStreamProvider);
    // Offline-first: while the first probe is in flight, fall back to the last
    // observed reading (offline until proven online) rather than optimistically
    // assuming online — otherwise an offline device renders the cloud-blue
    // "backed up" card, the Google button, the OR divider and the "Sign Up"
    // label instead of the coral offline warning + offline-acknowledge flow.
    final isOnline = connectivity.maybeWhen(
      data: (v) => v,
      orElse: () => lastKnownOnline,
    );

    return Scaffold(
      backgroundColor: AppColors.surfaceF3,
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
                  // AN-10: Center the card horizontally on wide (tablet)
                  // viewports. On a narrow phone the card fills the column
                  // naturally; on a wide viewport Center + maxWidth stops
                  // it left-anchoring as a narrow column on the left edge.
                  Center(
                    child: ConstrainedBox(
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
                                    l10n.signUpTitle,
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.signUpSubtitle,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: AppTheme.brandInkMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildAccountModeCard(
                                    theme: theme,
                                    isOnline: isOnline,
                                  ),
                                  const SizedBox(height: 22),
                                  if (isOnline) ...[
                                    _buildLabel(l10n.displayName),
                                    const SizedBox(height: 8),
                                    _buildAuthField(
                                      controller: _nameController,
                                      hintText: l10n.signUpScholarNameHint,
                                      suffixIcon: const Icon(
                                        Icons.face_outlined,
                                        color: AppTheme.brandInkMuted,
                                      ),
                                      textInputAction: TextInputAction.next,
                                      validator: (v) =>
                                          _validateDisplayName(v, l10n),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildLabel(l10n.signUpEmailAddressLabel),
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
                                      validator: (v) => _validateEmail(v, l10n),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildLabel(l10n.signUpPasswordLabel),
                                    const SizedBox(height: 8),
                                    _buildAuthField(
                                      controller: _passwordController,
                                      hintText: l10n.signUpPasswordHint,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      validator: (v) =>
                                          _validatePassword(v, l10n),
                                      onFieldSubmitted: (_) =>
                                          _signUpWithEmail(),
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePassword
                                            ? l10n.showPassword
                                            : l10n.hidePassword,
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.lock_rounded
                                              : Icons.visibility_rounded,
                                          color: AppTheme.brandInkMuted,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
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
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
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
                                            backgroundColor:
                                                AppTheme.transparent,
                                            shadowColor: AppTheme.transparent,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                )
                                              : Text(
                                                  l10n.signUpCta,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    // Offline: no email/password/name — an
                                    // explicit, credential-less device-local
                                    // account. Profiles are named individually
                                    // on the next screen.
                                    Text(
                                      l10n.signUpOfflineExplain,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.brandInkMuted,
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      height: 58,
                                      child: FilledButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _createOfflineAccount,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.brandBlue,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppTheme
                                                          .brandCreamCard,
                                                    ),
                                              )
                                            : Text(
                                                l10n.createOfflineAccount,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Center(
                                      child: TextButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _retryConnection,
                                        child: Text(l10n.signUpRetryConnection),
                                      ),
                                    ),
                                  ],
                                  if (isOnline) ...[
                                    const SizedBox(height: 18),
                                    Row(
                                      children: [
                                        const Expanded(child: Divider()),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          child: Text(
                                            l10n.signUpOrDivider,
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
                                    OutlinedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _signUpWithGoogle,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.brandInk,
                                        side: const BorderSide(
                                          color: AppTheme.brandInkSoft,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.g_mobiledata_rounded,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n.signUpGoogleCta,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  Center(
                                    child: RichText(
                                      text: TextSpan(
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              color: AppTheme.brandInkMuted,
                                            ),
                                        children: [
                                          TextSpan(
                                            text: l10n.signUpAlreadyExploring,
                                          ),
                                          TextSpan(
                                            text: l10n.signUpLogIn,
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
                  ), // Center
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
    final l10n = AppLocalizations.of(context)!;
    if (isOnline) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.brandBlueBright.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.brandBlueBright.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_done_rounded, color: AppTheme.brandBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.authModeCloud,
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

    // A single local-account notice. (Previously two near-identical
    // "no cloud backup / no device sync" cards were stacked here; the
    // redundant body card was removed — the title card already says it.)
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.brandCoralSoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.brandCoralDeep.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.brandCoralDeep,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.authModeLocalTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.brandInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      enabled: !_isLoading,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: [
        if (obscureText)
          const NoSpaceFormatter()
        else
          const TrimLeadingSpaceFormatter(),
      ],
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: AppTheme.brandInkMuted,
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: suffixIcon,
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
