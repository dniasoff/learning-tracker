import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/auth/domain/services/upgrade_to_cloud_service.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';

/// Local → cloud upgrade flow entry screen (Epic 20 v2 §4.3).
///
/// Minimum-viable implementation: verifies the user's local password,
/// creates a Firebase user, and delegates the atomic tier flip to
/// [UpgradeToCloudService]. Email-collision (existing Firebase account
/// with the same email) shows an explicit error block with the merge
/// options the story calls for — the actual merge of local data into
/// cloud is scoped to 20.11 + 20.12 (conflict resolution rules).
@RoutePage()
class UpgradeToCloudScreen extends ConsumerStatefulWidget {
  const UpgradeToCloudScreen({super.key});

  @override
  ConsumerState<UpgradeToCloudScreen> createState() =>
      _UpgradeToCloudScreenState();
}

enum _CollisionChoice { none, upload, discard }

class _UpgradeToCloudScreenState extends ConsumerState<UpgradeToCloudScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _cloudPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  bool _collision = false;
  bool _success = false;
  bool _discardAcknowledged = false;
  _CollisionChoice _choice = _CollisionChoice.none;

  @override
  void dispose() {
    _passwordController.dispose();
    _cloudPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final authState = ref.read(authStateProvider);
    final user = authState.currentUser;
    if (user == null || !authState.isLocalBorn) {
      setState(() => _error = 'Only local-born accounts can be upgraded.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _collision = false;
    });

    try {
      final dao = ref.read(userDatabaseProvider).userProfileDao;
      final profile = await dao.getUserProfileById(user.profileId);
      if (profile == null) throw StateError('Profile missing');

      final service = UpgradeToCloudService(
        dao: dao,
        firebaseAuth: ref.read(firebaseAuthProvider),
      );
      final upgraded = await service.upgrade(
        profile: profile,
        password: _passwordController.text,
      );

      ref
          .read(authStateProvider.notifier)
          .setCloudBornSession(profile: upgraded);
      if (mounted) setState(() => _success = true);
    } on UpgradePasswordMismatchException {
      if (mounted) {
        setState(() => _error = 'Incorrect password.');
      }
    } on EmailCollisionException {
      if (mounted) {
        setState(() => _collision = true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Upgrade failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Execute the user's collision resolution choice. Option A
  /// (upload) or Option B (discard) both require the cloud account
  /// password.
  Future<void> _executeCollisionChoice() async {
    if (_choice == _CollisionChoice.none) return;
    if (_cloudPasswordController.text.isEmpty) {
      setState(() => _error = 'Please enter your cloud account password.');
      return;
    }
    if (_choice == _CollisionChoice.discard && !_discardAcknowledged) {
      setState(
        () => _error =
            'Please acknowledge that local data will be replaced by cloud data.',
      );
      return;
    }

    final authState = ref.read(authStateProvider);
    final user = authState.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dao = ref.read(userDatabaseProvider).userProfileDao;
      final profile = await dao.getUserProfileById(user.profileId);
      if (profile == null) throw StateError('Profile missing');

      final service = UpgradeToCloudService(
        dao: dao,
        firebaseAuth: ref.read(firebaseAuthProvider),
      );

      final upgraded = _choice == _CollisionChoice.upload
          ? await service.executeUploadLocalIntoCloud(
              localProfile: profile,
              cloudPassword: _cloudPasswordController.text,
            )
          : await service.executeKeepCloudDiscardLocal(
              localProfile: profile,
              cloudPassword: _cloudPasswordController.text,
            );

      ref
          .read(authStateProvider.notifier)
          .setCloudBornSession(profile: upgraded);
      if (mounted) {
        setState(() {
          _success = true;
          _collision = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.code == 'wrong-password'
              ? 'Incorrect cloud account password.'
              : 'Sign-in failed: ${e.code}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Merge failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Cloud')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Back up your account',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  "You're signed in as ${authState.currentUser?.email ?? ''}. "
                  'Upgrading will create a cloud account with the same email '
                  'so your data syncs across devices. This is one-way — you '
                  "can't switch back to offline-only after upgrading.",
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (_success)
                  _SuccessBlock(theme: theme)
                else if (_collision)
                  _CollisionBlock(
                    theme: theme,
                    choice: _choice,
                    cloudPasswordController: _cloudPasswordController,
                    discardAcknowledged: _discardAcknowledged,
                    error: _error,
                    isLoading: _isLoading,
                    onChoose: (c) => setState(() {
                      _choice = c;
                      _error = null;
                    }),
                    onAcknowledge: (v) =>
                        setState(() => _discardAcknowledged = v ?? false),
                    onExecute: _executeCollisionChoice,
                    onCancel: () {
                      setState(() {
                        _collision = false;
                        _choice = _CollisionChoice.none;
                        _cloudPasswordController.clear();
                        _discardAcknowledged = false;
                        _error = null;
                      });
                    },
                  )
                else ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm your password',
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Password required' : null,
                    enabled: !_isLoading,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Upgrade to Cloud'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessBlock extends StatelessWidget {
  const _SuccessBlock({required this.theme});
  final ThemeData theme;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_done, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                "You're backed up!",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your data will now sync across devices automatically.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _CollisionBlock extends StatelessWidget {
  const _CollisionBlock({
    required this.theme,
    required this.choice,
    required this.cloudPasswordController,
    required this.discardAcknowledged,
    required this.error,
    required this.isLoading,
    required this.onChoose,
    required this.onAcknowledge,
    required this.onExecute,
    required this.onCancel,
  });

  final ThemeData theme;
  final _CollisionChoice choice;
  final TextEditingController cloudPasswordController;
  final bool discardAcknowledged;
  final String? error;
  final bool isLoading;
  final ValueChanged<_CollisionChoice> onChoose;
  final ValueChanged<bool?> onAcknowledge;
  final Future<void> Function() onExecute;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'A cloud account already exists with this email',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "We won't silently merge — choose how to resolve this:",
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _OptionTile(
            theme: theme,
            selected: choice == _CollisionChoice.upload,
            title: 'Upload local into cloud',
            subtitle:
                'Your offline progress merges with the existing cloud account.',
            onTap: isLoading ? null : () => onChoose(_CollisionChoice.upload),
          ),
          const SizedBox(height: 8),
          _OptionTile(
            theme: theme,
            selected: choice == _CollisionChoice.discard,
            title: 'Keep cloud, discard local',
            subtitle:
                'Sign in to the existing cloud account. Your local-only '
                'changes on this device are replaced with cloud data.',
            onTap: isLoading ? null : () => onChoose(_CollisionChoice.discard),
          ),
          if (choice != _CollisionChoice.none) ...[
            const SizedBox(height: 16),
            TextField(
              controller: cloudPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Cloud account password',
                hintText: 'The password for the existing cloud account',
              ),
              enabled: !isLoading,
            ),
            if (choice == _CollisionChoice.discard) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: discardAcknowledged,
                    onChanged: isLoading ? null : onAcknowledge,
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'I understand that cloud data will replace any '
                        'purely-local changes on this device.',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: isLoading ? null : onExecute,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      choice == _CollisionChoice.upload
                          ? 'Upload and sign in'
                          : 'Discard local and sign in',
                    ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: isLoading ? null : onCancel,
            child: const Text('Cancel — keep offline account'),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.theme,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final ThemeData theme;
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
