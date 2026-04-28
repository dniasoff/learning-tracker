import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/parent_mode/presentation/widgets/parent_mode_dialog_frame.dart';
import 'package:learning_tracker/features/parent_mode/presentation/widgets/parent_pin_setup_dialog.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
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
            error: (e, s) =>
                Center(child: Text(l10n.errorWithMessage(e.toString()))),
            data: (profiles) => _buildBody(context, profiles),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<ProfileModel> profiles) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
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
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.71,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: profiles.length + 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (_, index) {
                if (index == profiles.length) {
                  return _AddProfileCard(
                    onTap: () => _showAddDialog(profiles.length),
                    isDisabled: profiles.length >= 10,
                  );
                }
                final profile = profiles[index];
                return _ProfileCard(
                  profile: profile,
                  onTap: _isSelectingProfile
                      ? () {}
                      : () => unawaited(_selectProfile(profile.id)),
                  onLongPress: () => _showManageSheet(profile, profiles.length),
                );
              },
            ),
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
    final profileDao = ref.read(userDatabaseProvider).profileDao;
    final repo = ref.read(profileRepositoryProvider);

    final ctrl = TextEditingController();
    var mode = 'adult';
    String? err;

    final result = await showDialog<({String n, String m})>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final l10n = AppLocalizations.of(ctx)!;
          Future<void> check() async {
            set(() {});
            final n = ctrl.text.trim();
            if (n.isEmpty) {
              set(() => err = null);
              return;
            }
            try {
              final exists = await profileDao.profileExistsByName(1, n);
              set(() => err = exists ? l10n.profileNameAlreadyExists : null);
            } catch (_) {
              set(() => err = null);
            }
          }

          final theme = Theme.of(ctx);
          const surfaceGrey = Color(0xFFF2F4F7);
          const labelGrey = Color(0xFF333333);
          final canSubmit = ctrl.text.trim().isNotEmpty && err == null;
          final createProfileButton = SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSubmit
                  ? () => Navigator.pop(ctx, (n: ctrl.text.trim(), m: mode))
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
                textStyle: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(l10n.createProfile),
            ),
          );
          final createProfileCta = canSubmit
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.brandBlue.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: createProfileButton,
                )
              : createProfileButton;
          return ParentModeDialogFrame(
            title: l10n.addProfile,
            subtitle: l10n.addProfileDialogSubtitle,
            onClose: () => Navigator.pop(ctx),
            showCloseButton: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.whatsYourName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: labelGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.brandInk,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.enterNameHint,
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.brandInkSoft,
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor: surfaceGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(
                        color: AppTheme.brandBlue,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: theme.colorScheme.error),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(
                        color: theme.colorScheme.error,
                        width: 2,
                      ),
                    ),
                    errorText: err,
                    errorStyle: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onChanged: (_) => check(),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.chooseMode,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: labelGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AddProfileModePickCard(
                        selected: mode == 'child',
                        onTap: () => set(() => mode = 'child'),
                        icon: Icons.rocket_launch_rounded,
                        title: l10n.childModeCardTitle,
                        subtitle: l10n.childModeCardSubtitleFunRewards,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AddProfileModePickCard(
                        selected: mode == 'adult',
                        onTap: () => set(() => mode = 'adult'),
                        icon: Icons.menu_book_rounded,
                        title: l10n.adultModeCardTitle,
                        subtitle: l10n.adultModeCardSubtitleDeepFocused,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                createProfileCta,
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.brandInkMuted,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (result == null || !mounted) {
      // Delay dispose so the dialog exit animation finishes using the controller.
      Future.delayed(const Duration(milliseconds: 300), ctrl.dispose);
      return;
    }
    try {
      final created = await repo.createProfile(
        accountId: 1,
        displayName: result.n,
        mode: result.m,
      );
      // Dispose after creation (dialog animation is done by now).
      ctrl.dispose();
      // Manually refresh the profile list after creation.
      if (mounted) ref.invalidate(profileListProvider);
      // Child profiles require a parent PIN so the parent can gate access
      // to parental controls. Prompt right after creation.
      if (created.mode == 'child' && mounted) {
        await showParentPinSetupDialog(
          context,
          ref,
          profileId: created.id,
          profileName: created.displayName,
        );
      }
    } on DuplicateProfileNameException {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileNameTaken(result.n))),
        );
      }
    } on MaxProfilesExceededException {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.maxProfilesReached)));
      }
    }
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
                1,
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

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.deleteProfileTitle),
          content: Text(l10n.deleteProfileConfirm(profile.displayName)),
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
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (!(ok ?? false) || !mounted) return;
    try {
      await repo.deleteProfile(profile.id);
      final sel = ref.read(selectedProfileIdProvider) ?? -1;
      if (sel == profile.id) {
        ref.read(selectedProfileIdProvider.notifier).clear();
      }
      ref.invalidate(profileListProvider);
    } on LastProfileException {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.cannotDeleteOnlyProfile)));
      }
    }
  }
}

// ── Stateless card widgets ──────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final ProfileModel profile;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _ProfileCard({
    required this.profile,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isChild = profile.mode == 'child';
    const modeColor = AppTheme.brandBlue;
    final trimmedName = profile.displayName.trim();
    final firstLetter = trimmedName.isEmpty
        ? '?'
        : trimmedName.substring(0, 1).toUpperCase();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.brandCreamCard,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppTheme.brandOutline.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandInk.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: modeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isChild
                          ? l10n.profileBadgeChildMode
                          : l10n.profileBadgeAdultMode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.35,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppTheme.brandInkMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF2F5FC), Color(0xFFE6ECF8)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.brandBlue.withValues(alpha: 0.14),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          firstLetter,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppTheme.brandBlueDeep,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (isChild)
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF96B82),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.brandCreamCard,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Column(
                  children: [
                    Text(
                      profile.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: AppTheme.brandInk,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.tapToContinue,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.brandInkMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mode card for the add-profile dialog (child vs adult).
///
/// Uses a public class name so `Foo(...)` inside [State] is not mistaken for a
/// private instance member (library-private `_Foo` types can mis-resolve there).
class AddProfileModePickCard extends StatelessWidget {
  const AddProfileModePickCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;

  static const _surfaceGrey = Color(0xFFF2F4F7);
  static const _iconCircleMuted = Color(0xFFE4E8EF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 148,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : _surfaceGrey,
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? Border.all(color: AppTheme.brandBlue, width: 1.5)
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.brandBlue : _iconCircleMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: selected ? Colors.white : AppTheme.brandInkMuted,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppTheme.brandBlueDeep
                          : AppTheme.brandInk,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? AppTheme.brandBlue
                          : AppTheme.brandInkMuted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppTheme.brandBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDisabled;
  const _AddProfileCard({required this.onTap, this.isDisabled = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: isDisabled ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.brandCreamCard.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(30),
          ),
          child: CustomPaint(
            painter: _DashedRoundedRectPainter(
              color: isDisabled
                  ? AppTheme.brandOutline.withValues(alpha: 0.6)
                  : AppTheme.brandOutline,
              strokeWidth: 1.6,
              dashLength: 6,
              gapLength: 5,
              borderRadius: 30,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                    painter: _DashedCirclePainter(
                      color: isDisabled
                          ? AppTheme.brandOutline.withValues(alpha: 0.6)
                          : AppTheme.brandInkMuted,
                    ),
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: Center(
                        child: Icon(
                          Icons.add_rounded,
                          size: 44,
                          color: isDisabled
                              ? AppTheme.brandInkSoft
                              : AppTheme.brandBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isDisabled
                        ? l10n.maxProfilesLabel
                        : l10n.addProfileCardTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppTheme.brandInk,
                      fontWeight: FontWeight.w700,
                      height: 1.08,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDisabled
                        ? l10n.maxProfilesSubtitle
                        : l10n.createNewLearner,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.brandInkMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
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

class _DashedRoundedRectPainter extends CustomPainter {
  _DashedRoundedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.borderRadius,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    _drawDashedPath(canvas, path, paint, dashLength, gapLength);
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashLength != oldDelegate.dashLength ||
        gapLength != oldDelegate.gapLength ||
        borderRadius != oldDelegate.borderRadius;
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final path = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 2 - 2,
        ),
      );
    _drawDashedPath(canvas, path, paint, 6, 5);
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

void _drawDashedPath(
  Canvas canvas,
  Path source,
  Paint paint,
  double dashLength,
  double gapLength,
) {
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final next = distance + dashLength;
      canvas.drawPath(
        metric.extractPath(distance, next.clamp(0, metric.length)),
        paint,
      );
      distance = next + gapLength;
    }
  }
}
