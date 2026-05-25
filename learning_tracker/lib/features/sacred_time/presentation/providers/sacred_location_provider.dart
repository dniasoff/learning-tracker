import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/data/services/sacred_time_preferences.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'sacred_location_provider.g.dart';

@Riverpod(keepAlive: true)
LocationService locationService(Ref ref) => const LocationService();

/// Cached device location used for Sacred Time window calculation.
/// Survives app restarts via SharedPreferences. App-global (not per-profile).
@Riverpod(keepAlive: true)
class SacredLocationNotifier extends _$SacredLocationNotifier {
  @override
  SacredLocation? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
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
        final prefs = await SharedPreferences.getInstance();
        await SacredTimePreferences.writeLocation(prefs, result.location);
        await SacredTimePreferences.writeInIsrael(
          prefs,
          result.location.countryCode == 'IL',
        );
        state = result.location;
        ref.invalidate(inIsraelProvider);
        await _pushSnapshot();
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
          fields: {'message': result.message},
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
    final prefs = await SharedPreferences.getInstance();
    await SacredTimePreferences.writeLocation(prefs, loc);
    await SacredTimePreferences.writeInIsrael(prefs, countryCode == 'IL');
    state = loc;
    ref.invalidate(inIsraelProvider);
    await _pushSnapshot();
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
    state = loc;
    final prefs = await SharedPreferences.getInstance();
    await SacredTimePreferences.writeLocation(prefs, loc);
    await _pushSnapshot();
  }

  Future<void> _pushSnapshot() async {
    await ref.read(syncWriteFacadeProvider)?.pushUiPreferencesSnapshot();
  }
}

/// User-toggleable in-Israel flag. Auto-set by [SacredLocationNotifier.detect]
/// and [setManualCity] from the country code, but the user can flip freely
/// afterwards (e.g. visitors who keep two-day chag while in Israel).
@Riverpod(keepAlive: true)
class InIsraelNotifier extends _$InIsraelNotifier {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = SacredTimePreferences.readInIsrael(prefs);
    if (value != state) state = value;
  }

  Future<void> setInIsrael(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await SacredTimePreferences.writeInIsrael(prefs, value);
    await ref.read(syncWriteFacadeProvider)?.pushUiPreferencesSnapshot();
  }
}
