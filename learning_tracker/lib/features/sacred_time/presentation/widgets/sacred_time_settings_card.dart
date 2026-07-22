import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_error_code.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_fetch_result.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// AUD-sacred_time-08: whether Sacred Time's location actions (Detect /
/// Choose City) require a Parent PIN challenge before executing.
///
/// DEC-26 made location a DEVICE-scoped setting, so [SacredTimeSettingsCard]
/// is shown to every profile — including children — in Settings' DEVICE
/// section, and `SettingsRoute` itself carries no route-level PIN/child-mode
/// guard (see `app_router.dart`: `/` → `settings` vs. the PIN-guarded
/// `/parent-mode/*` routes). Changing the device's physical location is
/// still an escalating action from a child context, so it is gated the same
/// way ProfileSwitcherSheet gates its escalating actions (AN-2,
/// `switcherSheetPinGuardRequiredProvider`): true only when the active
/// profile is a child with a configured Parent PIN.
final sacredTimeLocationPinGuardRequiredProvider = FutureProvider<bool>((
  ref,
) async {
  final profiles =
      ref.watch(profileListStreamProvider).asData?.value ?? <ProfileModel>[];
  final activeId = ref.watch(activeProfileIdProvider);
  final active = profiles.where((p) => p.id == activeId).firstOrNull;
  if (active == null || active.profileMode != ProfileMode.child) return false;
  final pinService = ref.read(pinServiceProvider);
  return pinService.hasProfilePin(activeId);
});

/// Settings card for the Sacred Time feature. Hard-on (no disable toggle).
/// Lets the user choose location source (detect / manual city), refresh, and
/// flip the in-Israel one-day-chag override.
class SacredTimeSettingsCard extends ConsumerWidget {
  const SacredTimeSettingsCard({
    super.key,
    this.pinGuardRequired = false,
    this.activeProfileId = 0,
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
  final int activeProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final location = ref.watch(sacredLocationProvider);
    final inIsrael = ref.watch(inIsraelProvider);
    // Variant-aware Shabbos term, resolved once here at the Consumer layer and
    // composed into the localized header/description frames.
    final shabbos = domainTermLabels(
      ref,
    ).shabbos(variant: ref.watch(currentTransliterationVariantProvider));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
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
                _LocationRow(location: location),
                const SizedBox(height: 12),
                _LocationActions(
                  pinGuardRequired: pinGuardRequired,
                  activeProfileId: activeProfileId,
                ),
                const Divider(height: 28),
                _InIsraelRow(value: inIsrael),
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
  const _LocationRow({required this.location});

  final SacredLocation? location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final label = location == null
        ? l10n.sacredTimeNoLocation
        : (location!.cityLabel ??
              '${location!.latitude.toStringAsFixed(3)}, '
                  '${location!.longitude.toStringAsFixed(3)}');
    final sourceLabel = location == null
        ? null
        : switch (location!.source) {
            SacredLocationSource.detected => l10n.sacredTimeSourceDetected,
            SacredLocationSource.manualCity => l10n.sacredTimeSourceManualCity,
            SacredLocationSource.manualCoords =>
              l10n.sacredTimeSourceManualCoords,
          };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.place_outlined, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (sourceLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  sourceLabel,
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
  final int activeProfileId;

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
      final result = await ref.read(sacredLocationProvider.notifier).detect();
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
  Future<bool> _verifyParentPin() {
    final l10n = AppLocalizations.of(context)!;
    return showParentPinVerificationDialog(
      context,
      profileId: widget.activeProfileId,
      pinService: ref.read(pinServiceProvider),
      subtitle: l10n.pinDialogSubtitleLocationAccess,
    );
  }

  void _showOutcome(LocationFetchResult result) {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final message = switch (result) {
      LocationFetchSuccess() => l10n.sacredTimeLocationUpdated,
      LocationFetchPermissionDenied(:final permanentlyDenied) =>
        permanentlyDenied
            ? l10n.sacredTimeLocationPermissionPermanentlyDenied
            : l10n.sacredTimeLocationPermissionDenied,
      LocationFetchServiceDisabled() => l10n.sacredTimeLocationServicesOff,
      LocationFetchError(:final code) => _errorMessage(code, l10n),
    };
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

class _InIsraelRow extends ConsumerWidget {
  const _InIsraelRow({required this.value});

  final bool value;

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
          onChanged: (v) => ref.read(inIsraelProvider.notifier).setInIsrael(v),
        ),
      ],
    );
  }
}
