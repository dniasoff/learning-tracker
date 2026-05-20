import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_mode_pick_card.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_mode_dialog_frame.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_setup_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows the "Add Profile" dialog and handles the full creation flow including
/// optional Parent PIN prompt for child profiles.
///
/// Returns the created [ProfileModel], or null if the user cancelled.
Future<ProfileModel?> showAddProfileDialog(
  BuildContext context,
  WidgetRef ref,
) async {
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
            final exists = await profileDao.profileExistsByName(
              ref.read(currentAccountIdProvider),
              n,
            );
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
                inputFormatters: const [TrimLeadingSpaceFormatter()],
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

  if (result == null || !context.mounted) {
    Future.delayed(const Duration(milliseconds: 300), ctrl.dispose);
    return null;
  }

  try {
    final created = await repo.createProfile(
      accountId: ref.read(currentAccountIdProvider),
      displayName: result.n,
      mode: result.m,
    );
    ctrl.dispose();
    if (context.mounted) ref.invalidate(profileListProvider);
    if (created.profileMode.isChild && context.mounted) {
      await showParentPinSetupDialog(
        context,
        ref,
        profileId: created.id,
        profileName: created.displayName,
      );
    }
    return created;
  } on DuplicateProfileNameException {
    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileNameTaken(result.n))));
    }
  } on MaxProfilesExceededException {
    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.maxProfilesReached)));
    }
  } finally {
    // Ensure we always dispose (ctrl.dispose is idempotent).
  }
  return null;
}
