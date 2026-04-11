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

/// Dedicated local-born signup screen (Epic 20 v2 §4.2).
///
/// Shown when the device is offline at first launch. Collects email
/// + password, shows a hard warning block that cannot be dismissed,
/// and requires explicit acknowledgment that the account has no
/// backup and no recovery path before the "Create Offline Account"
/// button is enabled.
@RoutePage()
class LocalSignupScreen extends ConsumerStatefulWidget {
  const LocalSignupScreen({super.key});

  @override
  ConsumerState<LocalSignupScreen> createState() => _LocalSignupScreenState();
}

class _LocalSignupScreenState extends ConsumerState<LocalSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _acknowledged = false;
  String? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _acknowledged &&
      !_isLoading &&
      _nameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmPasswordController.text == _passwordController.text;

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_acknowledged) return;
    setState(() {
      _isLoading = true;
      _submitError = null;
    });
    try {
      final dao = ref.read(userDatabaseProvider).userProfileDao;
      final service = LocalAuthService(dao: dao);
      final profile = await service.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
        userMode: 'adult',
      );
      ref
          .read(auth_state.authStateProvider.notifier)
          .setLocalBornSession(profile: profile);
      if (mounted) {
        unawaited(context.router.push(const OnboardingRoute()));
      }
    } on DuplicateEmailException {
      setState(() =>
          _submitError = 'An offline account already exists on this device '
              'with that email.');
    } on InvalidInputException catch (e) {
      setState(() => _submitError = e.reason);
    } catch (e) {
      setState(() => _submitError = 'Signup failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WarningBlock(theme: theme),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your name',
                  ),
                  validator: validators.validateDisplayName,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
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
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'At least 8 characters',
                  ),
                  validator: validators.validatePassword,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                  validator: _validateConfirmPassword,
                  enabled: !_isLoading,
                  onFieldSubmitted: (_) => _canSubmit ? _submit() : null,
                ),
                const SizedBox(height: 24),
                _AcknowledgmentRow(
                  checked: _acknowledged,
                  onChanged: _isLoading
                      ? null
                      : (v) => setState(() => _acknowledged = v ?? false),
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
                      : const Text('Create Offline Account'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => context.router.maybePop(),
                  child: const Text('Wait for Internet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WarningBlock extends StatelessWidget {
  const _WarningBlock({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline Account — No Backup',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "You're signing up without an internet connection. This "
            'account exists only on this device. If you:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 8),
          _bullet(theme,
              'Forget your password → your account and all progress are '
              'unrecoverable'),
          _bullet(theme,
              'Lose or wipe this device → your data cannot be restored'),
          _bullet(theme,
              "Want to use the app on another device → you'll need to "
              'create a new account there'),
          const SizedBox(height: 12),
          Text(
            'When you connect to the internet later, you can optionally '
            'upgrade to a cloud-backed account in Settings.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              )),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcknowledgmentRow extends StatelessWidget {
  const _AcknowledgmentRow({required this.checked, required this.onChanged});
  final bool checked;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'I acknowledge my data will not be backed up',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: checked, onChanged: onChanged),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'I understand my data is not backed up and cannot be '
                'recovered if I forget my password or lose this device.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
