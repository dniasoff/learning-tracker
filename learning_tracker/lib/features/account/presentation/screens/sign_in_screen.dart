import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/presentation/notifiers/sign_in_controller.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/widgets/sign_in_actions.dart';
import 'package:learning_tracker/features/account/presentation/widgets/sign_in_form.dart';
import 'package:learning_tracker/features/account/presentation/widgets/sign_in_mode_card.dart';
import 'package:learning_tracker/features/onboarding/domain/validators/auth_validators.dart'
    as validators;
import 'package:learning_tracker/l10n/app_localizations.dart';

export 'package:learning_tracker/features/account/presentation/notifiers/sign_in_controller.dart'
    show
        SignInController,
        SignInError,
        SignInIdle,
        SignInState,
        SignInSubmitting,
        signInControllerProvider;
export 'package:learning_tracker/features/account/presentation/widgets/email_verification_dialog.dart'
    show showEmailVerificationDialog;
export 'package:learning_tracker/features/account/presentation/widgets/sign_in_actions.dart'
    show SignInActions;
export 'package:learning_tracker/features/account/presentation/widgets/sign_in_form.dart'
    show SignInForm;
export 'package:learning_tracker/features/account/presentation/widgets/sign_in_mode_card.dart'
    show RegistryMatchKind, SignInModeCard, SignInModeHint;

@RoutePage()
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _keepSignedIn = true;

  /// Set when the email matches a device-registry account (shown under field).
  String? _registryFoundHint;
  RegistryMatchKind _registryMatchKind = RegistryMatchKind.none;
  Timer? _emailDebounce;

  @override
  void initState() {
    super.initState();
    // Inject screen-level callbacks into the controller SYNCHRONOUSLY so they
    // are always registered before any user interaction can trigger sign-in.
    //
    // Previously these were set inside addPostFrameCallback, which introduced
    // a race: if signInWithEmail completed and raised an error before the
    // postFrameCallback fired (or on a controller rebuild), _showError was
    // null and the null-safe `?.call` silently dropped the error — the user
    // saw the screen return to sign-in with no snackbar (SI-WP-01).
    //
    // Moving the registration here is safe: context is available on
    // ConsumerStatefulWidget at initState time, and buildVerificationCallback
    // only captures the context reference — it does not call ScaffoldMessenger
    // or Navigator until the callback is actually invoked (async, well after
    // the first frame).
    ref
        .read(signInControllerProvider.notifier)
        .setCallbacks(
          showVerificationDialog: ref
              .read(signInControllerProvider.notifier)
              .buildVerificationCallback(context),
          showError: _showError,
        );
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Registry debounce ────────────────────────────────────────────────────────

  /// Epic 21.7: debounced live lookup against the device registry
  /// as the user types their email.
  void _onEmailChanged(String email) {
    _emailDebounce?.cancel();
    _emailDebounce = Timer(const Duration(milliseconds: 300), () async {
      final normalized = email.trim().toLowerCase();
      if (normalized.length < 5) {
        if (_registryMatchKind != RegistryMatchKind.none ||
            _registryFoundHint != null) {
          setState(() {
            _registryFoundHint = null;
            _registryMatchKind = RegistryMatchKind.none;
          });
        }
        return;
      }

      final registry = ref.read(deviceRegistryProvider);
      final account = await registry.findByEmail(normalized);

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        if (account != null) {
          final tierLabel = account.accountTier.isCloud
              ? l10n.authTierCloud
              : l10n.authTierLocal;
          _registryFoundHint = l10n.authFoundOnDevice(tierLabel);
          _registryMatchKind = account.accountTier.isLocal
              ? RegistryMatchKind.localBorn
              : RegistryMatchKind.cloudBorn;
        } else {
          _registryFoundHint = null;
          _registryMatchKind = RegistryMatchKind.notOnDevice;
        }
      });
    });
  }

  // ── Mode computation ─────────────────────────────────────────────────────────

  SignInModeHint _effectiveSignInMode({required bool isOnline}) {
    if (_emailController.text.trim().isEmpty) {
      return isOnline ? SignInModeHint.cloud : SignInModeHint.local;
    }
    switch (_registryMatchKind) {
      case RegistryMatchKind.none:
        return isOnline ? SignInModeHint.cloud : SignInModeHint.local;
      case RegistryMatchKind.localBorn:
        return SignInModeHint.local;
      case RegistryMatchKind.cloudBorn:
        return isOnline ? SignInModeHint.cloud : SignInModeHint.cloudOffline;
      case RegistryMatchKind.notOnDevice:
        return isOnline ? SignInModeHint.cloud : SignInModeHint.local;
    }
  }

  String? _registrySubtitle({
    required bool isOnline,
    required AppLocalizations l10n,
  }) {
    switch (_registryMatchKind) {
      case RegistryMatchKind.none:
        return null;
      case RegistryMatchKind.localBorn:
      case RegistryMatchKind.cloudBorn:
        return _registryFoundHint;
      case RegistryMatchKind.notOnDevice:
        return isOnline
            ? l10n.authNotOnDeviceCheckCloud
            : l10n.authNotOnDeviceOffline;
    }
  }

  // ── Error display ────────────────────────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.brandCoralDeep,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ── Sign-in dispatch ─────────────────────────────────────────────────────────

  Future<void> _handleSignInWithEmail(AppLocalizations l10n) async {
    await ref
        .read(signInControllerProvider.notifier)
        .signInWithEmail(
          email: _emailController.text.trim().toLowerCase(),
          password: _passwordController.text,
          router: context.router,
          l10n: l10n,
          formKey: _formKey,
        );
  }

  Future<void> _handleSignInWithGoogle(AppLocalizations l10n) async {
    await ref
        .read(signInControllerProvider.notifier)
        .signInWithGoogle(router: context.router, l10n: l10n);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final connectivity = ref.watch(connectivityStreamProvider);
    // Offline-first: while the first probe is in flight, fall back to the last
    // observed reading (offline until proven online) rather than optimistically
    // assuming online — otherwise an offline device renders the cloud-blue
    // "backed up" card and a tappable Google button for the whole probe window.
    final isOnline = connectivity.maybeWhen(
      data: (v) => v,
      orElse: () => lastKnownOnline,
    );
    final signInState = ref.watch(signInControllerProvider);
    final isLoading = signInState is SignInSubmitting;
    final signInMode = _effectiveSignInMode(isOnline: isOnline);
    final registrySubtitle = _registrySubtitle(isOnline: isOnline, l10n: l10n);

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
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
                          decoration: BoxDecoration(
                            color: AppTheme.brandCreamCard,
                            borderRadius: BorderRadius.circular(34),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.signInWelcomeBack,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.signInReady,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: AppTheme.brandInkMuted,
                                      height: 1.4,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              SignInModeCard(mode: signInMode, l10n: l10n),
                              const SizedBox(height: 26),
                              SignInForm(
                                formKey: _formKey,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                isLoading: isLoading,
                                obscurePassword: _obscurePassword,
                                keepSignedIn: _keepSignedIn,
                                registrySubtitle: registrySubtitle,
                                l10n: l10n,
                                onEmailChanged: _onEmailChanged,
                                onPasswordToggle: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                onKeepSignedInChanged: (value) => setState(
                                  () => _keepSignedIn = value ?? false,
                                ),
                                onSubmit: () => _handleSignInWithEmail(l10n),
                                validateEmail: validators.validateEmail,
                                validatePassword: (v) {
                                  if (v == null || v.isEmpty) {
                                    return l10n.authPasswordRequired;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              SignInActions(
                                isLoading: isLoading,
                                isOnline: isOnline,
                                l10n: l10n,
                                onSignIn: () => _handleSignInWithEmail(l10n),
                                onGoogleSignIn: () =>
                                    _handleSignInWithGoogle(l10n),
                                onRegister: () =>
                                    context.router.replace(SignupRoute()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
