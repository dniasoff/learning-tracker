import 'package:auto_route/auto_route.dart';
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

class _UpgradeToCloudScreenState
    extends ConsumerState<UpgradeToCloudScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  bool _collision = false;
  bool _success = false;

  @override
  void dispose() {
    _passwordController.dispose();
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
                  _CollisionBlock(theme: theme)
                else ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm your password',
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Password required'
                        : null,
                    enabled: !_isLoading,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style:
                          TextStyle(color: theme.colorScheme.error),
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
  const _CollisionBlock({required this.theme});
  final ThemeData theme;
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
            "We won't silently merge — you have to choose. Your options:",
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          const _Bullet(
            'Upload local into cloud — your offline progress merges with the '
            'existing cloud account using the conflict-resolution rules',
          ),
          const _Bullet(
            'Keep cloud, discard local — you sign in to the existing cloud '
            'account and your local-only data is removed (irreversible)',
          ),
          const _Bullet(
            'Cancel — back out, your local account stays untouched',
          ),
          const SizedBox(height: 12),
          Text(
            'Full merge UX ships with Epic 20 story 20.11 / 20.12. '
            'For now, use Cancel.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
