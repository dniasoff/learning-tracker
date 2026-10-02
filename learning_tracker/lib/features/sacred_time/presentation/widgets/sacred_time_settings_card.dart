import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_error_code.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_fetch_result.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_settings_editor_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// AUD-sacred_time-08: whether Sacred Time's settings actions (Detect /
/// Choose City / the in-Israel switch) require a Parent PIN challenge
/// before executing.
///
/// [SacredTimeSettingsCard] is shown to every profile — including children
/// — and `SettingsRoute` itself carries no route-level PIN/child-mode guard
/// (see `app_router.dart`: `/` → `settings` vs. the PIN-guarded
/// `/parent-mode/*` routes). Changing a learner's lock settings (AD-37,
/// DNI-481) is an escalating action from a child context, so it is gated
/// the same way ProfileSwitcherSheet gates its escalating actions (AN-2,
/// `switcherSheetPinGuardRequiredProvider`): true only when the active
/// profile is a child with a configured Parent PIN.
final sacredTimeLocationPinGuardRequiredProvider = FutureProvider<bool>((
  ref,
) async {
  final profiles =
      ref.watch(profileListStreamProvider).asData?.value ??
      <LearnerProfileEntity>[];
  // T-37: keyed on the DEVICE OWNER's own profile, not activeProfileIdProvider
  // (which redirects to the talmid's profileId during a tutored session):
  // the PIN gate evaluates whoever's holding the device — mirrors
  // switcherSheetPinGuardRequiredProvider's identical fix.
  final selectedId = ref.watch(selectedProfileIdProvider);
  final active = profiles.where((p) => p.profileId == selectedId).firstOrNull;
  if (active == null || active.mode != ProfileMode.child) return false;
  if (selectedId == null) return false;
  final pinService = ref.read(pinServiceProvider);
  return pinService.hasProfilePin(selectedId);
});

/// The profiles whose Parent PIN must be verified before the after-lock
/// location prompt (DNI-481 AC-2) may open the city picker for
/// [targetProfileId]; null when the action is refused outright.
///
/// The city picker edits the ACTIVE learner through governed writes, and a
/// prompt for another own learner first makes that learner the active one,
/// so the gate covers both ends of the action:
///  * the device holder: a child [selectedProfileId] with a Parent PIN (the
///    rule of [sacredTimeLocationPinGuardRequiredProvider]);
///  * the target: a child [targetProfileId] other than the selected one,
///    with a Parent PIN, is challenged on ITS OWN profile. An adult holder
///    never vouches for a child's PIN, so the picker never opens on a
///    guarded child that was not authenticated for this action.
/// A target that is not among the account's loaded [profiles] is refused
/// (fail closed).
Future<List<String>?> learnerLocationPromptPinChallenges({
  required String? selectedProfileId,
  required String targetProfileId,
  required List<LearnerProfileEntity> profiles,
  required Future<bool> Function(String profileId) hasProfilePin,
}) async {
  LearnerProfileEntity? byId(String? id) =>
      profiles.where((p) => p.profileId == id).firstOrNull;
  Future<bool> guarded(LearnerProfileEntity? profile) async =>
      profile != null &&
      profile.mode == ProfileMode.child &&
      await hasProfilePin(profile.profileId);

  final challenges = <String>[];
  final selected = byId(selectedProfileId);
  if (await guarded(selected)) challenges.add(selected!.profileId);
  if (targetProfileId == selectedProfileId) return challenges;
  final target = byId(targetProfileId);
  if (target == null) return null;
  if (await guarded(target)) challenges.add(target.profileId);
  return challenges;
}

/// Whether the holder of the device may set [targetProfileId]'s location
/// from the after-lock prompt (DNI-481 AC-2) now: every Parent PIN that
/// [learnerLocationPromptPinChallenges] names is asked for, in turn, on
/// [context] (a context under the root navigator); one cancel or wrong PIN
/// refuses. Used by the app before it switches to the target learner and
/// opens the city picker.
Future<bool> guardLearnerLocationPromptAccess(
  BuildContext context,
  WidgetRef ref,
  String targetProfileId,
) async {
  // The profile list is auto-disposed: hold a subscription while it loads.
  final subscription = ProviderScope.containerOf(
    context,
    listen: false,
  ).listen(profileListStreamProvider.future, (_, _) {});
  final List<LearnerProfileEntity> profiles;
  try {
    profiles = await subscription.read();
  } on Object {
    return false; // Fail closed: no profiles, no judgement, no picker.
  } finally {
    subscription.close();
  }
  final pinService = ref.read(pinServiceProvider);
  final challenges = await learnerLocationPromptPinChallenges(
    selectedProfileId: ref.read(selectedProfileIdProvider),
    targetProfileId: targetProfileId,
    profiles: profiles,
    hasProfilePin: pinService.hasProfilePin,
  );
  if (challenges == null) return false;
  for (final profileId in challenges) {
    if (!context.mounted) return false;
    if (!await _verifySacredTimeParentPin(context, ref, profileId)) {
      return false;
    }
  }
  return context.mounted;
}

/// Settings card for the Sacred Time feature. Hard-on (no disable toggle).
///
/// Shows and edits the ACTIVE LEARNER's lock settings (DNI-481 AC-3, AD-37):
/// the location (detect / choose a city) and the in-Israel one-day-chag
/// flag. Reads come from [activeLearnerSettingsProvider] (over
/// `learnerLockSettingsProvider`); every edit is a governed, logged
/// `learnerSettings` change through [learnerSettingsEditorProvider]. No
/// device preference is read or written.
class SacredTimeSettingsCard extends ConsumerWidget {
  const SacredTimeSettingsCard({
    super.key,
    this.pinGuardRequired = false,
    this.activeProfileId,
  });

  /// AUD-sacred_time-08: gates the location actions behind a Parent PIN
  /// challenge (see [sacredTimeLocationPinGuardRequiredProvider]).
  ///
  /// This card has no DB-backed provider dependency of its own — the caller
  /// (`SettingsScreen`, which already watches the active profile for other
  /// purposes) resolves the guard and threads it down as a plain bool/id
  /// pair. Callers that omit it (every pre-existing construction site,
  /// including tests) default to no guard, matching pre-fix behaviour.
  final bool pinGuardRequired;

  /// Active profile id passed through to the Parent PIN dialog. Ignored
  /// when [pinGuardRequired] is false.
  final String? activeProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(activeLearnerSettingsProvider);
    // Variant-aware Shabbos term, resolved once here at the Consumer layer and
    // composed into the localized header/description frames.
    final shabbos = domainTermLabels(
      ref,
    ).shabbos(variant: ref.watch(currentTransliterationVariantProvider));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.brandCreamCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: context.colors.notifCardShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _Header(theme: theme, shabbos: shabbos),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(
                    context,
                  )!.sacredTimeCardDescription(shabbos),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _LocationRow(settings: settings),
                const SizedBox(height: 12),
                _LocationActions(
                  pinGuardRequired: pinGuardRequired,
                  activeProfileId: activeProfileId,
                ),
                const Divider(height: 28),
                _InIsraelRow(
                  value: settings.asData?.value?.inIsrael ?? false,
                  enabled: settings.asData?.value != null,
                  pinGuardRequired: pinGuardRequired,
                  activeProfileId: activeProfileId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme, required this.shabbos});

  final ThemeData theme;

  /// Variant-resolved Shabbos term, uppercased for the mode label below.
  final String shabbos;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.sacredTimeHeaderBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_outlined, color: Colors.white, size: 17),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              AppLocalizations.of(
                context,
              )!.sacredTimeShabbosModeLabel(shabbos.toUpperCase()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
          ),
          const Spacer(),
          Text(
            AppLocalizations.of(context)!.sacredTimeAlwaysOn,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.settings});

  /// The active learner's current settings (loading / error / none).
  final AsyncValue<LearnerSettings?> settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final current = settings.asData?.value;
    final latitude = current?.latitude;
    final longitude = current?.longitude;
    // Coordinates are stored at 3 decimal places (PV-7); the row shows the
    // same precision.
    final label = latitude == null || longitude == null
        ? l10n.sacredTimeNoLocation
        : '${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.place_outlined, size: 20),
        const SizedBox(width: 10),
        Expanded(
          // While the settings load the row shows a neutral dash (no
          // indeterminate spinner: the card sits on the scrolling Settings
          // screen).
          child: settings.isLoading && current == null
              ? Text(
                  '—',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (current != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        current.timeZone,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _LocationActions extends ConsumerStatefulWidget {
  const _LocationActions({
    required this.pinGuardRequired,
    required this.activeProfileId,
  });

  final bool pinGuardRequired;
  final String? activeProfileId;

  @override
  ConsumerState<_LocationActions> createState() => _LocationActionsState();
}

class _LocationActionsState extends ConsumerState<_LocationActions> {
  bool _detecting = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _detecting ? null : _detect,
            icon: _detecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, size: 18),
            label: Text(AppLocalizations.of(context)!.sacredTimeDetect),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _detecting ? null : _pickCity,
            icon: const Icon(Icons.search, size: 18),
            label: Text(AppLocalizations.of(context)!.sacredTimeChooseCity),
          ),
        ),
      ],
    );
  }

  Future<void> _detect() async {
    // AUD-sacred_time-08: escalating action from a child context — verify
    // the Parent PIN first (mirrors ProfileSwitcherSheet's AN-2
    // `_guardEscalating`). Checked before `_detecting` flips so a cancelled
    // PIN prompt never leaves the button stuck in its loading state.
    if (widget.pinGuardRequired && !await _verifyParentPin()) return;
    if (!mounted) return;
    setState(() => _detecting = true);
    try {
      final result = await ref.read(learnerSettingsEditorProvider).detect();
      if (!mounted) return;
      _showOutcome(result);
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _pickCity() async {
    // AUD-sacred_time-08: same escalating-action gate as _detect above.
    if (widget.pinGuardRequired && !await _verifyParentPin()) return;
    if (!mounted) return;
    await context.pushRoute(const CityPickerRoute());
  }

  /// AUD-sacred_time-08: shows the Parent PIN verification dialog and
  /// returns whether it succeeded. Mirrors ProfileSwitcherSheet's
  /// `_guardEscalating` (AN-2).
  Future<bool> _verifyParentPin() =>
      _verifySacredTimeParentPin(context, ref, widget.activeProfileId);

  void _showOutcome(LearnerLocationDetectResult detected) {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final result = detected.fetch;
    final message = switch (result) {
      LocationFetchSuccess() => _editOutcomeMessage(
        detected.outcome,
        l10n,
        saved: l10n.sacredTimeLocationUpdated,
      ),
      LocationFetchPermissionDenied(:final permanentlyDenied) =>
        permanentlyDenied
            ? l10n.sacredTimeLocationPermissionPermanentlyDenied
            : l10n.sacredTimeLocationPermissionDenied,
      LocationFetchServiceDisabled() => l10n.sacredTimeLocationServicesOff,
      LocationFetchError(:final code) => _errorMessage(code, l10n),
    };
    if (message == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Resolves a [LocationErrorCode] to a localized, user-facing string.
  ///
  /// AUD-sacred_time-03 (EH-5): [LocationFetchError] carries a stable code,
  /// never a pre-formatted message — this exhaustive switch is the single
  /// place that maps each code to user-facing text. The exception's raw
  /// text (exposed only via [LocationFetchError.debugDetail] for logs) must
  /// never reach this switch or be rendered.
  String _errorMessage(LocationErrorCode code, AppLocalizations l10n) {
    return switch (code) {
      LocationErrorCode.timeout => l10n.sacredTimeLocationDetectErrorTimeout,
      LocationErrorCode.unknown => l10n.sacredTimeLocationDetectErrorGeneric,
    };
  }
}

/// AUD-sacred_time-08: shows the Parent PIN verification dialog for
/// [activeProfileId] and returns whether it succeeded. Mirrors
/// ProfileSwitcherSheet's `_guardEscalating` (AN-2); fails closed when there
/// is nothing to verify against.
Future<bool> _verifySacredTimeParentPin(
  BuildContext context,
  WidgetRef ref,
  String? activeProfileId,
) {
  if (activeProfileId == null) return Future.value(false);
  final l10n = AppLocalizations.of(context)!;
  return showParentPinVerificationDialog(
    context,
    profileId: activeProfileId,
    pinService: ref.read(pinServiceProvider),
    subtitle: l10n.pinDialogSubtitleLocationAccess,
  );
}

/// The message for a settings edit [outcome]; [saved] when it was written,
/// null for no message.
String? _editOutcomeMessage(
  LearnerSettingsEditOutcome? outcome,
  AppLocalizations l10n, {
  String? saved,
}) => switch (outcome) {
  LearnerSettingsEditOutcome.saved || null => saved,
  LearnerSettingsEditOutcome.locked ||
  LearnerSettingsEditOutcome.notSaved => l10n.sacredTimeSettingsNotSaved,
  LearnerSettingsEditOutcome.unavailable => l10n.sacredTimeSettingsUnavailable,
};

class _InIsraelRow extends ConsumerWidget {
  const _InIsraelRow({
    required this.value,
    required this.enabled,
    required this.pinGuardRequired,
    required this.activeProfileId,
  });

  /// The learner's current flag (`false` when never set: diaspora).
  final bool value;

  /// False while no learner's settings are loaded.
  final bool enabled;

  /// AUD-sacred_time-08: the switch changes a learner setting, so it is
  /// gated like the location actions.
  final bool pinGuardRequired;
  final String? activeProfileId;

  Future<void> _set(BuildContext context, WidgetRef ref, bool next) async {
    if (pinGuardRequired &&
        !await _verifySacredTimeParentPin(context, ref, activeProfileId)) {
      return;
    }
    final outcome = await ref
        .read(learnerSettingsEditorProvider)
        .setInIsrael(next);
    if (!context.mounted) return;
    final message = _editOutcomeMessage(outcome, AppLocalizations.of(context)!);
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Icon(Icons.flag_outlined, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.sacredTimeInIsraelTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppLocalizations.of(context)!.sacredTimeInIsraelSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: enabled ? (v) => _set(context, ref, v) : null,
        ),
      ],
    );
  }
}
