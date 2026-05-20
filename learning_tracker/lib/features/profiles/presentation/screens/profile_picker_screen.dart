import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/network_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/widgets/no_backup_badge.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/my_children_section.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/tutored_children_section.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

export 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_mode_pick_card.dart'
    show AddProfileModePickCard;

@RoutePage()
class ProfilePickerScreen extends ConsumerStatefulWidget {
  const ProfilePickerScreen({super.key});

  @override
  ConsumerState<ProfilePickerScreen> createState() =>
      _ProfilePickerScreenState();
}

class _ProfilePickerScreenState extends ConsumerState<ProfilePickerScreen> {
  bool _isSelectingProfile = false;

  @override
  Widget build(BuildContext context) {
    // Use future provider instead of stream provider to avoid the
    // InheritedElement '_dependents.isEmpty' assertion that fires when
    // a stream-triggered rebuild races with dialog/overlay dismissal.
    final profilesAsync = ref.watch(profileListProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.brandCreamCard,
              AppTheme.brandBlueSoft.withValues(alpha: 0.22),
              AppTheme.brandCream,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: profilesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => AppErrorView(
              error: e,
              stackTrace: s,
              onRetry: () => ref.refresh(profileListProvider),
            ),
            data: (profiles) => _buildBody(context, profiles),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<ProfileModel> profiles) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // ── Segmentation counts ───────────────────────────────────────────────
    final ownChildCount = profiles
        .where((p) => p.profileMode == ProfileMode.child)
        .length;

    // Read (not watch) the grants here so we can compute tutoredCount for
    // header logic without blocking on the async result — TutoredChildrenSection
    // handles the async display independently.  A null/loading result is
    // treated as 0 grants for the purpose of header visibility.
    final grantsAsync = ref.watch(incomingTutorGrantsProvider);
    final tutoredCount =
        grantsAsync.asData?.value.where((g) => g.grantState.isActive).length ??
        0;

    final isSegmented = ownChildCount > 0 || tutoredCount > 0;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            // DNI-342 / UX-DR20: persistent "no backup" badge for local-born
            // accounts (hidden for cloudBorn / signed-out via the widget's
            // internal tier gate).
            const Align(alignment: Alignment.center, child: NoBackupBadge()),
            const SizedBox(height: 6),
            Text(
              l10n.profilePickerTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: AppTheme.brandBlueDeep,
                letterSpacing: -0.8,
                height: 1.03,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.profilePickerSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.brandInkMuted,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            // ── Own profiles section ──────────────────────────────────────
            OwnProfilesSection(
              profiles: profiles,
              showHeader: isSegmented,
              isSelectingProfile: _isSelectingProfile,
              onProfileTap: (id) => unawaited(_selectProfile(id)),
              onProfileLongPress: (profile, count) =>
                  unawaited(_showManageSheet(profile, count)),
              onAddProfile: (_) => unawaited(_showAddDialog(profiles.length)),
            ),
            // ── "CHILD PROFILES" sub-section header ───────────────────────
            // Shown after the own-grid when child profiles exist (segmented).
            if (isSegmented && ownChildCount > 0) const ChildProfilesSection(),
            // ── Talmid (tutored) section (W6.14) ─────────────────────────
            const TutoredChildrenSection(),
          ],
        ),
      ),
    );
  }

  // ── Select Profile ─────────────────────────────────────────────────────────

  Future<void> _selectProfile(int profileId) async {
    if (_isSelectingProfile) return;
    _isSelectingProfile = true;

    try {
      ref.read(selectedProfileIdProvider.notifier).select(profileId);

      if (!mounted) return;
      await context.router.replaceAll([const AppShellRoute()]);
    } finally {
      // If navigation didn't happen (or failed), allow another tap attempt.
      if (mounted) {
        setState(() {
          _isSelectingProfile = false;
        });
      }
    }
  }

  // ── Add Profile ───────────────────────────────────────────────────────────

  Future<void> _showAddDialog(int profileCount) async {
    if (!mounted) return;
    await showAddProfileDialog(context, ref);
  }

  // ── Manage (Long-press) ───────────────────────────────────────────────────

  Future<void> _showManageSheet(ProfileModel profile, int profileCount) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(l10n.renameAction),
                onTap: () => Navigator.pop(ctx, 'rename'),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(
                  l10n.delete,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                enabled: profileCount > 1,
                subtitle: profileCount <= 1
                    ? Text(l10n.mustKeepOneProfile)
                    : null,
                onTap: profileCount > 1
                    ? () => Navigator.pop(ctx, 'delete')
                    : null,
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      await _showRenameDialog(profile);
    } else if (action == 'delete' && mounted) {
      await _showDeleteDialog(profile);
    }
  }

  // ── Rename ────────────────────────────────────────────────────────────────

  Future<void> _showRenameDialog(ProfileModel profile) async {
    final profileDao = ref.read(userDatabaseProvider).profileDao;
    final repo = ref.read(profileRepositoryProvider);

    final ctrl = TextEditingController(text: profile.displayName);
    String? err;
    final name = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final l10n = AppLocalizations.of(ctx)!;
          Future<void> check() async {
            final n = ctrl.text.trim();
            if (n.isEmpty) {
              set(() => err = null);
              return;
            }
            try {
              final exists = await profileDao.profileExistsByName(
                ref.read(currentAccountIdProvider),
                n,
                excludeId: profile.id,
              );
              set(() => err = exists ? l10n.profileNameAlreadyExists : null);
            } catch (_) {
              set(() => err = null);
            }
          }

          return AlertDialog(
            title: Text(l10n.renameProfileTitle),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              inputFormatters: const [TrimLeadingSpaceFormatter()],
              decoration: InputDecoration(
                labelText: l10n.displayName,
                border: const OutlineInputBorder(),
                errorText: err,
              ),
              onChanged: (_) => check(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: ctrl.text.trim().isNotEmpty && err == null
                    ? () => Navigator.pop(ctx, ctrl.text.trim())
                    : null,
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
    if (name == null || name.isEmpty || !mounted) {
      Future.delayed(const Duration(milliseconds: 300), ctrl.dispose);
      return;
    }
    try {
      await repo.updateProfile(id: profile.id, displayName: name);
      ctrl.dispose();
      if (mounted) ref.invalidate(profileListProvider);
    } on DuplicateProfileNameException {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileNameTaken(name))));
      }
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _showDeleteDialog(ProfileModel profile) async {
    final repo = ref.read(profileRepositoryProvider);
    final remaining = await repo.countProfilesForAccount(
      ref.read(currentAccountIdProvider),
    );
    final isLast = remaining <= 1;
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(
            isLast ? 'Delete your only profile?' : l10n.deleteProfileTitle,
          ),
          content: Text(
            isLast
                ? 'This is your only profile. Deleting '
                      '"${profile.displayName}" will erase every track, '
                      'completion, and lifetime entry on this account. You '
                      'will need to create a new profile before you can keep '
                      'learning.'
                : l10n.deleteProfileConfirm(profile.displayName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isLast ? 'Delete anyway' : l10n.delete),
            ),
          ],
        );
      },
    );
    if (!(ok ?? false) || !mounted) return;

    final isLocalBorn = ref.read(authStateProvider).isLocalBorn;
    if (!isLocalBorn) {
      final isOnline = await ref.read(connectivityServiceProvider).isOnline;
      if (!isOnline) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                )!.errorDeleteProfileRequiresInternet,
              ),
            ),
          );
        }
        return;
      }
    }

    await repo.deleteProfile(profile.id, allowLast: isLast);
    final sel = ref.read(selectedProfileIdProvider) ?? -1;
    if (sel == profile.id) {
      ref.read(selectedProfileIdProvider.notifier).clear();
    }
    ref.invalidate(profileListProvider);
  }
}
