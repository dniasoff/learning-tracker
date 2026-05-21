import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LWW merger for the `ui_preferences/data` Firestore document
/// (W2.27 / closes M1).
///
/// UI preferences are stored as a single Firestore document and written to
/// [SharedPreferences] via [ProfileScopedPreferenceKeys]. The row passed to
/// [merge] is a synthetic single-element list (see [PullPipeline.pullDocument]).
///
/// Firestore shape (from SyncEngine._mergeUiPreferences):
///   updated_at, app_locale, use_hebrew_calendar,
///   text_display.{font_size_index, show_nikud},
///   learning_order_parent_controls, hebrew_terms_script,
///   sacred_time.{latitude, longitude, country_code, city_label, source,
///               fixed_at_ms, in_israel}
///
/// Plan §F Phase 5 deliverable 7 — sacred_time is *device*-level (lat/lon/
/// timezone/in-israel describe the physical device, not a learner) so it
/// rides along on every profile's UI-prefs snapshot. The merger applies
/// the incoming block to SharedPreferences regardless of profileId.
///
/// Phase 3: the merger consults [MergeStore.remoteIsNewer] (clock-skew
/// arbitration), and after a successful apply calls
/// [MergeStore.persistUpdatedAt] so the persisted LWW timestamp survives
/// SharedPreferences resets. The SharedPreferences key is kept up to date
/// in parallel because the rest of the app reads it directly.
class UiPreferencesMerger implements EntityMerger {
  const UiPreferencesMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;

  /// Single natural key — UI preferences are a per-profile singleton.
  static const _naturalKey = 'data';

  @override
  String get kind => EntityKind.uiPreferences;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (rows.isEmpty) return;
    final remote = rows.first;
    if (remote.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final remoteUpdatedAt = _parseTimestamp(remote['updated_at']);
    final remoteSyncedAt = _parseTimestamp(remote['synced_at']);
    var localUpdatedAt = await _store.currentUpdatedAt(
      kind: kind,
      profileId: profileId,
      naturalKey: _naturalKey,
    );
    if (localUpdatedAt == null) {
      final localMs = prefs.getInt(
        ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(profileId),
      );
      if (localMs != null) {
        localUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
          localMs,
          isUtc: true,
        );
      }
    }
    final localSyncedAt = await _store.currentSyncedAt(
      kind: kind,
      profileId: profileId,
      naturalKey: _naturalKey,
    );

    if (!_store.remoteIsNewer(
      localUpdatedAt: localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt,
      localSyncedAt: localSyncedAt,
      remoteSyncedAt: remoteSyncedAt,
    )) {
      return;
    }

    final locale = remote['app_locale'] as String?;
    if (locale != null && (locale == 'en' || locale == 'he')) {
      await prefs.setString(
        ProfileScopedPreferenceKeys.appLocale(profileId),
        locale,
      );
    }

    final hebrew = remote['use_hebrew_calendar'];
    if (hebrew is bool) {
      await prefs.setBool(
        ProfileScopedPreferenceKeys.useHebrewCalendar(profileId),
        hebrew,
      );
    }

    final textDisplay = remote['text_display'] as Map<String, dynamic>?;
    if (textDisplay != null) {
      final idx = textDisplay['font_size_index'];
      if (idx is int && idx >= 0 && idx <= 2) {
        await prefs.setInt(
          ProfileScopedPreferenceKeys.textFontSize(profileId),
          idx,
        );
      }
      final nikud = textDisplay['show_nikud'];
      if (nikud is bool) {
        await prefs.setBool(
          ProfileScopedPreferenceKeys.textShowNikud(profileId),
          nikud,
        );
      }
    }

    final learningOrder = remote['learning_order_parent_controls'];
    if (learningOrder is bool) {
      await prefs.setBool(
        ProfileScopedPreferenceKeys.learningOrderParentControls(profileId),
        learningOrder,
      );
    }

    final hebrewTermsScript = remote['hebrew_terms_script'];
    if (hebrewTermsScript is bool) {
      await prefs.setBool(
        ProfileScopedPreferenceKeys.hebrewTermsScript(profileId),
        hebrewTermsScript,
      );
    }

    // Sacred Time settings are device-global (lat/lon/timezone/in-israel
    // describe the device, not a learner). Plan §F Phase 5 deliverable 7 —
    // every profile's UI-prefs snapshot carries the same block, so apply
    // it on every merge regardless of profileId.
    final sacredTime = remote['sacred_time'];
    if (sacredTime is Map<String, dynamic>) {
      final lat = sacredTime['latitude'];
      final lon = sacredTime['longitude'];
      if (lat is num && lon is num) {
        await prefs.setDouble('sacred_time_latitude', lat.toDouble());
        await prefs.setDouble('sacred_time_longitude', lon.toDouble());
      }
      final country = sacredTime['country_code'];
      if (country is String && country.isNotEmpty) {
        await prefs.setString('sacred_time_country_code', country);
      }
      final city = sacredTime['city_label'];
      if (city is String && city.isNotEmpty) {
        await prefs.setString('sacred_time_city_label', city);
      }
      final source = sacredTime['source'];
      if (source is String && source.isNotEmpty) {
        await prefs.setString('sacred_time_source', source);
      }
      final fixedAt = sacredTime['fixed_at_ms'];
      if (fixedAt is int) {
        await prefs.setInt('sacred_time_fixed_at_ms', fixedAt);
      }
      final inIsrael = sacredTime['in_israel'];
      if (inIsrael is bool) {
        await prefs.setBool('sacred_time_in_israel', inIsrael);
      }
    }

    final stamp = remoteUpdatedAt ?? DateTimeFactory.nowUtc();
    await prefs.setInt(
      ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(profileId),
      stamp.millisecondsSinceEpoch,
    );
    await _store.persistUpdatedAt(
      kind: kind,
      profileId: profileId,
      naturalKey: _naturalKey,
      updatedAt: stamp,
      syncedAt: remoteSyncedAt,
    );
  }

  DateTime? _parseTimestamp(Object? raw) => FirestoreCodec.parseDateTime(raw);
}
