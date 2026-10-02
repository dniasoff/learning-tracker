/// AD-41 civil dates: the learner's local calendar day of an instant.
library;

import 'package:learning_tracker/domain/learner_state/c0_stub.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';

/// A civil date in `YYYY-MM-DD` form (AD-41). Validate with `isCivilDate`
/// from `storage_codec.dart`.
typedef CivilDate = String;

/// The civil date of [instantUtc] in the `time_zone` in force at that
/// instant according to [settingsHistory] (AD-41).
///
/// C0 stub, filled by DNI-466 (1.4).
CivilDate civilDate(
  DateTime instantUtc,
  LearnerSettingsHistory settingsHistory,
) => c0Stub('DNI-466', 'civilDate');
