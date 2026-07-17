import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/guarded_persist.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/data/services/sacred_time_preferences.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_fetch_result.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'sacred_location_provider.g.dart';

// keepAlive: stateless facade wrapping platform geolocation calls; cheap to keep for the app's lifetime, avoids rebuild churn for its dependents.
@Riverpod(keepAlive: true)
LocationService locationService(Ref ref) => const LocationService();

/// Cached device location used for Sacred Time window calculation.
/// Survives app restarts via SharedPreferences. App-global (not per-profile).
// keepAlive: mirrors a persisted preference read on cold start; must survive widget unmounts so it isn't reloaded on every rebuild.
@Riverpod(keepAlive: true)
class SacredLocationNotifier extends _$SacredLocationNotifier {
  @override
  SacredLocation? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // After the async gap the provider may have been invalidated/disposed (e.g.
    // an account switch rebuilds it). Never write state on a disposed notifier.
    if (!ref.mounted) return;
    final loc = SacredTimePreferences.readLocation(prefs);
    if (loc != null) state = loc;
  }

  /// Whether the user can flip in-Israel — false until we have any location at
  /// all, since auto-detect derives the default from country.
  Future<LocationFetchResult> detect() async {
    // Instrumented so a "couldn't get location" report is diagnosable from
    // Send Diagnostic Logs: the outcome (service off / permission / timeout /
    // success) is otherwise only shown as a transient snackbar and never logged.
    AppLogger.instance.info(event: 'sacred_location_detect_started');
    final result = await ref.read(locationServiceProvider).detectCurrent();
    switch (result) {
      case LocationFetchSuccess():
        AppLogger.instance.info(
          event: 'sacred_location_detect_success',
          fields: {'country': result.location.countryCode ?? 'unknown'},
        );
        // AUD-sacred_time-01 (SM-4): after the detectCurrent() await above
        // the provider may have been invalidated/disposed (e.g. an account
        // switch mid-GPS-fetch). Never touch ref/state on a disposed
        // notifier.
        if (!ref.mounted) return result;
        final previous = state;
        state = result.location;
        // AUD-core-preferences-04 (EH-2): guard the persistence chain so a
        // write failure logs + rolls back state instead of leaving the
        // detected location (and the in-Israel flag derived from it)
        // silently unpersisted while the UI already shows it as set.
        await guardedPersist(
          event: 'sacred_location_detect_persist_failed',
          write: () async {
            final prefs = await SharedPreferences.getInstance();
            await SacredTimePreferences.writeLocation(prefs, result.location);
            await SacredTimePreferences.writeInIsrael(
              prefs,
              result.location.countryCode == 'IL',
            );
            // AUD-sacred_time-01 (SM-4): after the awaits above the provider
            // may have been invalidated/disposed (e.g. an account switch
            // mid-GPS-fetch). Never touch ref on a disposed notifier.
            if (!ref.mounted) return;
            ref.invalidate(inIsraelProvider);
            await _pushSnapshot();
          },
          onFailure: () {
            // AUD-sacred_time-01 (SM-4): never write state on a disposed
            // notifier.
            if (ref.mounted) state = previous;
          },
        );
      case LocationFetchServiceDisabled():
        AppLogger.instance.warning(
          event: 'sacred_location_detect_service_disabled',
        );
      case LocationFetchPermissionDenied():
        AppLogger.instance.warning(
          event: 'sacred_location_detect_permission_denied',
          fields: {'permanently': result.permanentlyDenied},
        );
      case LocationFetchError():
        AppLogger.instance.warning(
          event: 'sacred_location_detect_error',
          fields: {
            'code': result.code.name,
            if (result.debugDetail != null) 'debugDetail': result.debugDetail,
          },
        );
    }
    return result;
  }

  Future<void> setManualCity({
    required double latitude,
    required double longitude,
    required String cityLabel,
    required String countryCode,
  }) async {
    final loc = SacredLocation(
      latitude: latitude,
      longitude: longitude,
      source: SacredLocationSource.manualCity,
      fixedAt: DateTimeFactory.nowUtc(),
      countryCode: countryCode,
      cityLabel: cityLabel,
    );
    final previous = state;
    state = loc;
    // AUD-core-preferences-04 (EH-2): see [detect]'s success branch.
    await guardedPersist(
      event: 'sacred_location_set_manual_city_persist_failed',
      write: () async {
        final prefs = await SharedPreferences.getInstance();
        await SacredTimePreferences.writeLocation(prefs, loc);
        await SacredTimePreferences.writeInIsrael(prefs, countryCode == 'IL');
        // AUD-sacred_time-01 (SM-4): after the awaits above the provider
        // may have been invalidated/disposed (e.g. an account switch).
        // Never touch ref on a disposed notifier.
        if (!ref.mounted) return;
        ref.invalidate(inIsraelProvider);
        await _pushSnapshot();
      },
      onFailure: () {
        if (ref.mounted) state = previous;
      },
    );
  }

  Future<void> setManualCoords({
    required double latitude,
    required double longitude,
  }) async {
    // Manual coords don't carry country info — keep the existing in-Israel
    // toggle untouched so the user controls it.
    final loc = SacredLocation(
      latitude: latitude,
      longitude: longitude,
      source: SacredLocationSource.manualCoords,
      fixedAt: DateTimeFactory.nowUtc(),
    );
    final previous = state;
    state = loc;
    // AUD-core-preferences-04 (EH-2): see [detect]'s success branch.
    await guardedPersist(
      event: 'sacred_location_set_manual_coords_persist_failed',
      write: () async {
        final prefs = await SharedPreferences.getInstance();
        await SacredTimePreferences.writeLocation(prefs, loc);
        // AUD-sacred_time-01 (SM-4): after the await above the provider
        // may have been invalidated/disposed (e.g. an account switch).
        // Never touch ref on a disposed notifier.
        if (!ref.mounted) return;
        await _pushSnapshot();
      },
      onFailure: () {
        if (ref.mounted) state = previous;
      },
    );
  }

  Future<void> _pushSnapshot() async {
    if (!ref.mounted) return;
    await ref.read(syncWriteFacadeProvider)?.pushUiPreferencesSnapshot();
  }
}

/// User-toggleable in-Israel flag. Auto-set by [SacredLocationNotifier.detect]
/// and [setManualCity] from the country code, but the user can flip freely
/// afterwards (e.g. visitors who keep two-day chag while in Israel).
// keepAlive: the notifier's own _explicitlySet guard must survive widget unmounts, or a rebuild would drop it and let a stale async _load() clobber an explicit user choice.
@Riverpod(keepAlive: true)
class InIsraelNotifier extends _$InIsraelNotifier {
  /// True once an explicit [setInIsrael] has run for this notifier instance.
  /// Guards against the build-time async [_load] resuming AFTER an explicit
  /// set and clobbering it with a stale prefs value. Resets on each rebuild
  /// (a location change invalidates this provider → new instance → reload from
  /// the new country default), which is the intended semantics.
  bool _explicitlySet = false;

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // Bail if disposed (account switch) or if an explicit setInIsrael() already
    // ran during the async gap — a stale prefs read must not clobber the user's
    // manual choice (the visitor "two-day chag" flip: non-IL city + inIsrael=true).
    if (!ref.mounted || _explicitlySet) return;
    final value = SacredTimePreferences.readInIsrael(prefs);
    if (value != state) state = value;
  }

  Future<void> setInIsrael(bool value) async {
    _explicitlySet = true;
    final previous = state;
    state = value;
    // AUD-core-preferences-04 (EH-2): see SacredLocationNotifier.detect's
    // success branch.
    await guardedPersist(
      event: 'in_israel_set_persist_failed',
      write: () async {
        final prefs = await SharedPreferences.getInstance();
        await SacredTimePreferences.writeInIsrael(prefs, value);
        // AUD-sacred_time-01 (SM-4): after the await above the provider
        // may have been invalidated/disposed (e.g. an account switch).
        // Never touch ref on a disposed notifier.
        if (!ref.mounted) return;
        await ref.read(syncWriteFacadeProvider)?.pushUiPreferencesSnapshot();
      },
      onFailure: () {
        if (ref.mounted) state = previous;
      },
    );
  }
}
