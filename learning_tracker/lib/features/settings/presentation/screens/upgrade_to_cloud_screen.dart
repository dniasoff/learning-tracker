import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/features/account/domain/services/upgrade_to_cloud_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/widgets/email_verification_confirm_panel.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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

// ---------------------------------------------------------------------------
// Sealed state machine — replaces four booleans (_isLoading, _collision,
// _success, _verificationRequired) that previously formed an implicit state
// machine.  Exactly one variant is active at any point in time.
// ---------------------------------------------------------------------------

sealed class _UpgradePhase {
  const _UpgradePhase();
}

/// Default form state — user can fill in their password and submit.
final class _PhaseForm extends _UpgradePhase {
  const _PhaseForm({this.error, this.isLoading = false});
  final String? error;
  final bool isLoading;
}

/// Email-verification pending — user must click the inbox link.
final class _PhaseVerifying extends _UpgradePhase {
  const _PhaseVerifying({required this.bodyText, this.isLoading = false});
  final String bodyText;
  final bool isLoading;
}

/// Email collision detected — user must choose how to resolve it.
final class _PhaseCollision extends _UpgradePhase {
  const _PhaseCollision({
    this.choice = _CollisionChoice.none,
    this.discardAcknowledged = false,
    this.error,
    this.isLoading = false,
  });
  final _CollisionChoice choice;
  final bool discardAcknowledged;
  final String? error;
  final bool isLoading;
}

/// Upgrade completed successfully.
final class _PhaseSuccess extends _UpgradePhase {
  const _PhaseSuccess();
}

// ---------------------------------------------------------------------------

class _UpgradeToCloudScreenState extends ConsumerState<UpgradeToCloudScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _cloudPasswordController = TextEditingController();

  _UpgradePhase _phase = const _PhaseForm();

  Future<bool> _requireInternet() async {
    final checker = ref.read(internetConnectionCheckerProvider);
    final hasConnection = await checker.hasConnection;
    if (!hasConnection && mounted) {
      setState(
        () => _phase = const _PhaseForm(
          error:
              'Internet connection is required to upgrade to cloud. '
              'Your account and data stay local until you retry online.',
        ),
      );
    }
    return hasConnection;
  }

  Future<void> _pushLocalDataAfterUpgrade() async {
    // S7: do NOT invalidate syncEngineProvider — the SyncOrchestrator is a
    // per-session singleton and an invalidate used to rebuild it, registering
    // duplicate lifecycle observers / Firestore listeners (Bug #1). The
    // cloud-born tier flip is already reflected via authStateProvider, which
    // both the engine and the orchestrator gate on; just trigger the push +
    // pull directly on the orchestrator.
    final orchestrator = ref.read(syncOrchestratorProvider);
    if (orchestrator == null) return;
    await orchestrator.pushAllLocalData();
    await orchestrator.pullOnLaunch();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _cloudPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _requireInternet()) return;

    final authState = ref.read(authStateProvider);
    final user = authState.currentUser;
    if (user == null || !authState.isLocalBorn) {
      setState(
        () => _phase = const _PhaseForm(
          error: 'Only local-born accounts can be upgraded.',
        ),
      );
      return;
    }

    setState(() => _phase = const _PhaseForm(isLoading: true));

    try {
      final dao = ref.read(userDatabaseProvider).userProfileDao;
      final profile = await dao.getUserProfileById(user.profileId);
      if (profile == null) throw StateError('Profile missing');
      final registry = ref.read(deviceRegistryProvider);
      final account = await registry.findByEmail(profile.email);

      final service = UpgradeToCloudService(
        dao: dao,
        authRepository: ref.read(authRepositoryProvider),
        registry: registry,
        accountId: account?.accountId,
      );
      final upgraded = await service.upgrade(
        profile: profile,
        password: _passwordController.text,
      );

      ref
          .read(authStateProvider.notifier)
          .setCloudBornSession(profile: upgraded);
      await _pushLocalDataAfterUpgrade();
      if (mounted) setState(() => _phase = const _PhaseSuccess());
    } on UpgradeEmailNotVerifiedException {
      if (mounted) {
        setState(
          () => _phase = const _PhaseVerifying(
            bodyText:
                'We sent a confirmation link to your inbox. After you verify, '
                'tap "I\'ve verified — complete upgrade" below.',
          ),
        );
      }
    } on UpgradePasswordMismatchException {
      if (mounted) {
        setState(() => _phase = const _PhaseForm(error: 'Incorrect password.'));
      }
    } on EmailCollisionException {
      if (mounted) setState(() => _phase = const _PhaseCollision());
    } catch (e) {
      if (mounted) {
        final code = _extractFirebaseCode(e);
        setState(
          () => _phase = _PhaseForm(
            error: code == 'network-request-failed'
                ? 'Internet connection is required to upgrade to cloud.'
                : 'Upgrade failed: $e',
          ),
        );
      }
    }
  }

  /// Extracts the Firebase error code from an exception (if present).
  String? _extractFirebaseCode(Object e) {
    final str = e.toString();
    final match = RegExp(r'\[([a-z-]+)\]').firstMatch(str);
    return match?.group(1);
  }

  Future<void> _resendVerification() async {
    if (!await _requireInternet()) return;
    final authState = ref.read(authStateProvider);
    final user = authState.currentUser;
    if (user == null) return;

    // Preserve the current body text while loading.
    final currentBodyText = switch (_phase) {
      _PhaseVerifying(:final bodyText) => bodyText,
      _ => '',
    };
    setState(
      () =>
          _phase = _PhaseVerifying(bodyText: currentBodyText, isLoading: true),
    );

    try {
      final dao = ref.read(userDatabaseProvider).userProfileDao;
      final profile = await dao.getUserProfileById(user.profileId);
      if (profile == null) throw StateError('Profile missing');
      final registry = ref.read(deviceRegistryProvider);
      final account = await registry.findByEmail(profile.email);
      final service = UpgradeToCloudService(
        dao: dao,
        authRepository: ref.read(authRepositoryProvider),
        registry: registry,
        accountId: account?.accountId,
      );
      await service.resendUpgradeVerification(
        profile: profile,
        password: _passwordController.text,
      );
      if (mounted) {
        setState(() => _phase = _PhaseVerifying(bodyText: currentBodyText));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.errorVerificationEmailSent,
              ),
            ),
          );
        }
      }
    } on UpgradePasswordMismatchException {
      if (mounted) {
        setState(() => _phase = const _PhaseForm(error: 'Incorrect password.'));
      }
    } on EmailCollisionException {
      if (mounted) setState(() => _phase = const _PhaseCollision());
    } catch (_) {
      if (mounted) {
        setState(() => _phase = _PhaseVerifying(bodyText: currentBodyText));
      }
    }
  }

  /// Execute the user's collision resolution choice. Option A
  /// (upload) or Option B (discard) both require the cloud account
  /// password.
  Future<void> _executeCollisionChoice() async {
    final collision = _phase;
    if (collision is! _PhaseCollision) return;
    if (collision.choice == _CollisionChoice.none) return;
    if (!await _requireInternet()) return;
    if (_cloudPasswordController.text.isEmpty) {
      setState(
        () => _phase = _PhaseCollision(
          choice: collision.choice,
          discardAcknowledged: collision.discardAcknowledged,
          error: 'Please enter your cloud account password.',
        ),
      );
      return;
    }
    if (collision.choice == _CollisionChoice.discard &&
        !collision.discardAcknowledged) {
      setState(
        () => _phase = _PhaseCollision(
          choice: collision.choice,
          discardAcknowledged: collision.discardAcknowledged,
          error:
              'Please acknowledge that local data will be replaced by cloud data.',
        ),
      );
      return;
    }

    final authState = ref.read(authStateProvider);
    final user = authState.currentUser;
    if (user == null) return;

    setState(
      () => _phase = _PhaseCollision(
        choice: collision.choice,
        discardAcknowledged: collision.discardAcknowledged,
        isLoading: true,
      ),
    );

    try {
      final dao = ref.read(userDatabaseProvider).userProfileDao;
      final profile = await dao.getUserProfileById(user.profileId);
      if (profile == null) throw StateError('Profile missing');
      final registry = ref.read(deviceRegistryProvider);
      final account = await registry.findByEmail(profile.email);

      final service = UpgradeToCloudService(
        dao: dao,
        authRepository: ref.read(authRepositoryProvider),
        registry: registry,
        accountId: account?.accountId,
      );

      final upgraded = collision.choice == _CollisionChoice.upload
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
      await _pushLocalDataAfterUpgrade();
      if (mounted) setState(() => _phase = const _PhaseSuccess());
    } on UpgradeEmailNotVerifiedException {
      if (mounted) {
        setState(
          () => _phase = const _PhaseVerifying(
            bodyText:
                'This cloud account is not verified yet. Check your inbox, '
                'then tap "I\'ve verified — complete upgrade" below.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final code = _extractFirebaseCode(e);
        setState(
          () => _phase = _PhaseCollision(
            choice: collision.choice,
            discardAcknowledged: collision.discardAcknowledged,
            error: code == 'wrong-password'
                ? 'Incorrect cloud account password.'
                : code == 'network-request-failed'
                ? 'Internet connection is required to complete this merge option.'
                : 'Merge failed: $e',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.upgradeToCloudTitle),
      ),
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
                switch (_phase) {
                  _PhaseSuccess() => _SuccessBlock(theme: theme),
                  _PhaseVerifying(:final bodyText, :final isLoading) =>
                    _VerificationRequiredBlock(
                      email: authState.currentUser?.email,
                      bodyText: bodyText,
                      isLoading: isLoading,
                      onIVerified: _submit,
                      onResend: _resendVerification,
                      onCancel: () =>
                          setState(() => _phase = const _PhaseForm()),
                    ),
                  _PhaseCollision(
                    :final choice,
                    :final discardAcknowledged,
                    :final error,
                    :final isLoading,
                  ) =>
                    _CollisionBlock(
                      theme: theme,
                      choice: choice,
                      cloudPasswordController: _cloudPasswordController,
                      discardAcknowledged: discardAcknowledged,
                      error: error,
                      isLoading: isLoading,
                      onChoose: (c) => setState(
                        () => _phase = _PhaseCollision(
                          choice: c,
                          discardAcknowledged: discardAcknowledged,
                        ),
                      ),
                      onAcknowledge: (v) => setState(
                        () => _phase = _PhaseCollision(
                          choice: choice,
                          discardAcknowledged: v ?? false,
                        ),
                      ),
                      onExecute: _executeCollisionChoice,
                      // AN-5 fix: "Cancel — keep offline account" must exit the
                      // collision block and return to the form (keeping local
                      // data), NOT reset to _PhaseCollision which stays inside
                      // the collision UI with no observable change for the user.
                      // Mirrors _VerificationRequiredBlock's onCancel which
                      // correctly returns to _PhaseForm.
                      onCancel: () {
                        _cloudPasswordController.clear();
                        setState(() => _phase = const _PhaseForm());
                      },
                    ),
                  _PhaseForm(:final error, :final isLoading) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        inputFormatters: const [NoSpaceFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Confirm your password',
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Password required'
                            : null,
                        enabled: !isLoading,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                AppLocalizations.of(
                                  context,
                                )!.upgradeToCloudButton,
                              ),
                      ),
                    ],
                  ),
                },
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
              inputFormatters: const [NoSpaceFormatter()],
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
            child: Text(
              AppLocalizations.of(context)!.upgradeToCloudCancelKeepOffline,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationRequiredBlock extends StatelessWidget {
  const _VerificationRequiredBlock({
    required this.email,
    required this.bodyText,
    required this.isLoading,
    required this.onIVerified,
    required this.onResend,
    required this.onCancel,
  });

  final String? email;
  final String bodyText;
  final bool isLoading;
  final Future<void> Function() onIVerified;
  final Future<void> Function() onResend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: EmailVerificationConfirmPanel(
        email: email,
        bodyText: bodyText,
        verifiedLinkLabel: "I've verified — complete upgrade",
        actionsLocked: isLoading,
        onSendAgain: onResend,
        onCancel: onCancel,
        onVerified: onIVerified,
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
