import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
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
    barrierDismissible: false,
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
          } catch (e, st) {
            // AUD-profiles-16 (EH-3): the live duplicate-name check is
            // best-effort — a DB failure here must not block typing, so we
            // still clear the error and let the user proceed (the real
            // duplicate-name guard runs again, non-silently, inside
            // repo.createProfile below). But it must be logged: previously
            // this was a bare `catch (_)` with zero telemetry trail.
            AppLogger.instance.warning(
              event: 'add_profile_dialog_duplicate_check_failed',
              exception: e,
              stackTrace: st,
            );
            set(() => err = null);
          }
        }

        final theme = Theme.of(ctx);
        final surfaceGrey = context.colors.brandCreamSoft;
        // AUD-profiles dark-mode sweep: was a hardcoded `Color(0xFF333333)`
        // on this dialog's `brandCreamCard` surface (DARKENS in dark) —
        // measured 1.38:1 in dark. `addProfileFormLabel` lightens like
        // `brandInk` in dark (14.94:1 against the darkened card).
        final labelGrey = context.colors.addProfileFormLabel;
        final canSubmit = ctrl.text.trim().isNotEmpty && err == null;
        // AUD-profiles dark-mode sweep: `brandBlue` LIGHTENS in dark (an
        // ink/contrast-role token, not a "stays deep" fill), so a hardcoded
        // `Colors.white` label on top of it dropped to 2.52:1 in dark.
        // `colorScheme.onPrimary` is the theme's own contrast-verified ink
        // for this exact fill: white in light (unchanged), near-black in
        // dark (~7.59:1).
        final onAccent = theme.colorScheme.onPrimary;
        final createProfileButton = SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canSubmit
                ? () => Navigator.pop(ctx, (n: ctrl.text.trim(), m: mode))
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.brandBlue,
              foregroundColor: onAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
              textStyle: theme.textTheme.titleSmall?.copyWith(
                color: onAccent,
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
                      color: context.colors.brandBlue.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: createProfileButton,
              )
            : createProfileButton;
        return PopScope(
          canPop: false,
          child: ParentModeDialogFrame(
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
                  // Profile names are stored verbatim; soft-keyboard autocorrect
                  // was mangling typed names (e.g. "Talmid1" -> "Talmid16").
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: const [TrimLeadingSpaceFormatter()],
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: context.colors.brandInk,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.enterNameHint,
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: context.colors.brandInkSoft,
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
                      borderSide: BorderSide(
                        color: context.colors.brandBlue,
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
                    foregroundColor: context.colors.brandInkMuted,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
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
    if (context.mounted) ref.invalidate(profileListProvider);
    // P2-24: select() runs for EVERY newly-created profile, not just child
    // ones. **`repo.createProfile` above activates NOTHING (T-49, P2-30) —
    // this `select()` call is the ONLY thing that moves either
    // `selectedProfileIdProvider` or `activeProfileDocIdProvider`, for
    // either mode.** That is exactly WHY it must run unconditionally: P2-24's
    // conclusion (gating on `isChild` alone was wrong) is unchanged, but its
    // premise (P2-23's repo-side activation) is inverted — the repo used to
    // activate `activeProfileDocIdProvider` unconditionally while this
    // `select()` call, gated on `isChild`, moved `selectedProfileIdProvider`
    // only for a child profile, splitting the two providers on every adult
    // creation; P2-30 removed the repo-side write entirely, so today,
    // omitting this call for an adult profile would leave BOTH providers on
    // the OLD profile instead — still wrong, for a different reason. This
    // matches every other creation call site in the app
    // (`onboarding_profile_creation_step.dart`, `AutoSelectedProfileId`'s
    // self-heal branch), which already select() the profile they just
    // created regardless of mode.
    if (context.mounted) {
      ref
          .read(selectedProfileIdProvider.notifier)
          .select(created.id, ulid: created.ulid);
    }
    if (created.profileMode.isChild && context.mounted) {
      // PP-13: update the active-profile context to the newly-created child
      // profile so the app-shell header shows the new profile's identity during
      // the forced PIN setup — not the previously-active profile's stale chrome.
      // (The select() call that used to live here, gated on isChild, moved
      // above so BOTH modes select consistently; only the PIN dialog itself
      // stays child-only.)
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
  } catch (e, st) {
    // D4: previously, any non-(Duplicate/Max) failure here — e.g. an
    // account_id FK violation when currentAccountId doesn't match the active
    // DB's accounts row — was silently swallowed: the dialog just closed with
    // no profile created and NO feedback. Surface it (log + snackbar) so a
    // failed creation is never a silent no-op.
    AppLogger.instance.error(
      event: 'profile_create_failed',
      fields: {'name': result.n, 'mode': result.m},
      exception: e,
      stackTrace: st,
    );
    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.unexpectedError)));
    }
  } finally {
    // Dispose after the dialog has fully animated out — disposing immediately
    // (while the dialog's TextField may still be mounted during teardown)
    // triggers a "used after dispose" assertion. This single delayed dispose
    // covers every try/catch path (success, Duplicate, Max, and generic error),
    // replacing the prior immediate success-path dispose + error-path leak.
    Future.delayed(const Duration(milliseconds: 300), ctrl.dispose);
  }
  return null;
}
