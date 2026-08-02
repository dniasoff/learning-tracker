import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
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
/// Firestore shape:
///   updated_at, app_locale, use_hebrew_calendar,
///   text_display.{font_size_index, show_nikud},
///   learning_order_parent_controls, hebrew_terms_script
///
/// DEC-26 (WS6) — sacred_time (location) is Device-scoped and is no longer
/// embedded in the per-profile ui_preferences document. Sacred-time prefs are
/// stored in device-global SharedPreferences keys via [SacredTimePreferences]
/// and are not read or written here. Removing them from this merger eliminates
/// the LWW cross-profile clobber: two profiles on the same device no longer
/// overwrite the shared device location on every sync round-trip.
///
/// Phase 3: the merger consults [MergeStore.remoteIsNewer] (clock-skew
/// arbitration), and after a successful apply calls
/// [MergeStore.persistUpdatedAt] so the persisted LWW timestamp survives
/// SharedPreferences resets. The SharedPreferences key is kept up to date
/// in parallel because the rest of the app reads it directly.
class UiPreferencesMerger implements EntityMerger {
  const UiPreferencesMerger({required MergeStore store, AppLogger? logger})
    : _store = store,
      _logger = logger;

  final MergeStore _store;
  // AUD-core-sync-15: optional logger so a merge failure is observable
  // instead of silently swallowed.
  final AppLogger? _logger;

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

    // AUD-core-sync-15: isolate this document's merge — a malformed/throwing
    // payload must not abort the whole sync pull step for other kinds.
    try {
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

      // DEC-26 (WS6) — sacred_time (location) is Device-scoped and is no
      // longer part of the per-profile ui_preferences document. Any `sacred_time`
      // block present in older Firestore documents is deliberately ignored here
      // so that syncing a second profile cannot overwrite the device-global
      // location that was set via SacredTimePreferences on this device. The
      // local read path (SacredTimePreferences.readLocation) is unchanged.

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
    } on Exception catch (e, stackTrace) {
      _logger?.warning(
        event: 'sync_ui_preferences_merge_row_failed',
        fields: {'profile_id': profileId},
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  DateTime? _parseTimestamp(Object? raw) => FirestoreCodec.parseDateTime(raw);
}
