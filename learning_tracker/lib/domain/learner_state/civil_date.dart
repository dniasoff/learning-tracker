/// AD-41 civil dates: the learner's local calendar day of an instant.
library;

import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';

/// A civil date in `YYYY-MM-DD` form (AD-41). Validate with `isCivilDate`
/// from `storage_codec.dart`.
typedef CivilDate = String;

/// The civil date of [instantUtc] in the `time_zone` in force at that
/// instant according to [settingsHistory] (AD-41).
///
/// Never reads the device offset. A `time_zone` that is not in the tz
/// database falls back to UTC (story assumption: no device substitution).
CivilDate civilDate(
  DateTime instantUtc,
  LearnerSettingsHistory settingsHistory,
) {
  final zone = LearnerZone.of(settingsHistory.at(instantUtc).timeZone);
  return formatCivilDay(zone.dayOf(instantUtc));
}
