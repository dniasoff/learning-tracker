/// The governed `learnerSettings` change a Sacred Time settings edit
/// writes (AD-37, AD-38; DNI-481 AC-3).
///
/// A learner's location, IANA `time_zone`, Israel / chutz la'aretz flag,
/// tzeis minhag, and candle-lighting offset are fields of
/// `learner_profiles/{profileId}` and change only through
/// `LearningCommands.applyGovernedChange` (DNI-470), which logs one
/// `learnerSettings` change-log entry per edit. The settings history built
/// from those entries keeps every past lock window on the settings in force
/// at its instant (`lockWindows`), so an edit moves only later windows.
///
/// Nothing here reads device preferences: the values come from the parent's
/// edit (a detected fix, a chosen city or the Israel switch).
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// One parent edit of a learner's lock settings. Only the fields given
/// change; `latitude` and `longitude` are given together or not at all.
final class LearnerSettingsEdit {
  /// Creates an edit.
  const LearnerSettingsEdit({
    this.latitude,
    this.longitude,
    this.timeZone,
    this.inIsrael,
    this.yomTovDays,
    this.tzeisMinhag,
    this.candleLightingMinutes,
    this.locationSource,
    this.locationFixedAt,
  });

  /// The new latitude in degrees.
  final double? latitude;

  /// The new longitude in degrees.
  final double? longitude;

  /// The new IANA time zone id.
  final String? timeZone;

  /// The new Israel (one-day yom tov) flag.
  final bool? inIsrael;

  /// The canonical one- or two-day minhag.
  final int? yomTovDays;

  final String? tzeisMinhag;
  final int? candleLightingMinutes;
  final String? locationSource;
  final DateTime? locationFixedAt;

  /// Whether the edit changes nothing.
  bool get isEmpty =>
      latitude == null &&
      longitude == null &&
      timeZone == null &&
      inIsrael == null &&
      yomTovDays == null &&
      tzeisMinhag == null &&
      candleLightingMinutes == null &&
      locationSource == null &&
      locationFixedAt == null;

  @override
  bool operator ==(Object other) =>
      other is LearnerSettingsEdit &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.timeZone == timeZone &&
      other.inIsrael == inIsrael &&
      other.yomTovDays == yomTovDays &&
      other.tzeisMinhag == tzeisMinhag &&
      other.candleLightingMinutes == candleLightingMinutes &&
      other.locationSource == locationSource &&
      other.locationFixedAt == locationFixedAt;

  @override
  int get hashCode => Object.hash(
    latitude,
    longitude,
    timeZone,
    inIsrael,
    yomTovDays,
    tzeisMinhag,
    candleLightingMinutes,
    locationSource,
    locationFixedAt,
  );

  @override
  String toString() =>
      'LearnerSettingsEdit(location: ${latitude != null}, '
      'timeZone: $timeZone, yomTovDays: $yomTovDays, inIsrael: $inIsrael)';
}

/// Rounds a coordinate to 3 decimal places (about 111 m) before it is
/// stored (PV-7: a full-precision fix can pinpoint a home; the zmanim need
/// no more than about 100 m).
double roundLearnerCoordinate(double value) => (value * 1000).round() / 1000;

/// The one-entity [GovernedAction] that writes [edit] onto the
/// `learner_profiles/{profileId}` doc of [profileId] (mode `update`: the
/// profile must exist). Coordinates are rounded with
/// [roundLearnerCoordinate].
///
/// Throws [ArgumentError] when [edit] is empty, gives only one coordinate,
/// or holds a value the AD-52 settings codec refuses (a coordinate out of
/// range, a time zone that is not an IANA id).
GovernedAction learnerSettingsAction(
  String profileId,
  LearnerSettingsEdit edit,
) {
  if (edit.isEmpty) {
    throw ArgumentError.value(edit, 'edit', 'changes nothing');
  }
  final latitude = edit.latitude == null
      ? null
      : roundLearnerCoordinate(edit.latitude!);
  final longitude = edit.longitude == null
      ? null
      : roundLearnerCoordinate(edit.longitude!);
  try {
    // Validates the given values with the settings codec; the placeholder
    // zone stands in only when the edit leaves the zone unchanged.
    LearnerSettings(
      profileId: profileId,
      timeZone: edit.timeZone ?? 'UTC',
      latitude: latitude,
      longitude: longitude,
      inIsrael: edit.inIsrael,
      yomTovDays: edit.yomTovDays,
      tzeisMinhag: edit.tzeisMinhag ?? LearnerSettings.defaultTzeisMinhag,
      candleLightingMinutes:
          edit.candleLightingMinutes ??
          LearnerSettings.defaultCandleLightingMinutes,
      locationSource: edit.locationSource,
      locationFixedAt: edit.locationFixedAt,
    ).toStorage();
  } on StorageFormatException catch (e) {
    throw ArgumentError.value(edit, 'edit', e.toString());
  }
  return GovernedAction([
    GovernedEntityChange(
      entity: GovernedEntity.learnerSettings,
      entityId: profileId,
      docs: [
        GovernedDocPatch(
          collection: GovernedEntity.learnerSettings.collection,
          docId: profileId,
          mode: DocMode.update,
          fields: {
            if (latitude != null) LearnerSettings.kLatitude: latitude,
            if (longitude != null) LearnerSettings.kLongitude: longitude,
            if (edit.timeZone != null) LearnerSettings.kTimeZone: edit.timeZone,
            if (edit.yomTovDays != null) ...{
              LearnerSettings.kYomTovDays: edit.yomTovDays,
              LearnerSettings.kInIsrael: edit.yomTovDays == 1,
            } else if (edit.inIsrael != null)
              LearnerSettings.kInIsrael: edit.inIsrael,
            if (edit.tzeisMinhag != null)
              LearnerSettings.kTzeisMinhag: edit.tzeisMinhag,
            if (edit.candleLightingMinutes != null)
              LearnerSettings.kCandleLightingMinutes:
                  edit.candleLightingMinutes,
            if (edit.locationSource != null)
              LearnerSettings.kLocationSource: edit.locationSource,
            if (edit.locationFixedAt != null)
              LearnerSettings.kLocationFixedAt: edit.locationFixedAt!.toUtc(),
          },
        ),
      ],
    ),
  ]);
}
