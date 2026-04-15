import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/auth/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart'
    as auth_state;
import 'package:learning_tracker/features/onboarding/domain/validators/auth_validators.dart'
    as validators;

/// Sign-in screen for existing local-born accounts.
///
/// Counterpart to [LocalSignupScreen]. Shown when a user with an
/// existing offline account needs to re-authenticate (after sign-out,
/// or when picking between multiple local accounts on the device).
@RoutePage()
class LocalSignInScreen extends ConsumerStatefulWidget {
  const LocalSignInScreen({super.key});

  @override
  ConsumerState<LocalSignInScreen> createState() => _LocalSignInScreenState();
}

class _LocalSignInScreenState extends ConsumerState<LocalSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _submitError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_isLoading &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _submitError = null;
    });
    try {
      final dao = ref.read(userDatabaseProvider).userProfileDao;
      final service = LocalAuthService(dao: dao);
      final profile = await service.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      ref
          .read(auth_state.authStateProvider.notifier)
          .setLocalBornSession(profile: profile);
      if (mounted) {
        unawaited(context.router.replaceAll([const OnboardingRoute()]));
      }
    } on InvalidCredentialsException {
      setState(() => _submitError = 'Incorrect email or password.');
    } catch (e) {
      setState(() => _submitError = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign In (Offline)')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign in to your offline account',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the email and password you used when you '
                  'created your offline account on this device.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'name@example.com',
                  ),
                  validator: validators.validateEmail,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: validators.validatePassword,
                  enabled: !_isLoading,
                  onFieldSubmitted: (_) => _canSubmit ? _submit() : null,
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _submitError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => context.router.replace(LocalSignupRoute()),
                  child: const Text("Don't have an account? Create one"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
