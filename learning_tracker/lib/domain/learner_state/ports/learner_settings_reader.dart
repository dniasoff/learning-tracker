/// Port for the current AD-37 learner settings of one profile — the
/// `learnerSettings` fields of `learner_profiles/{profileId}` — that
/// `learnerLockSettingsProvider` combines with the change log
/// (`LearnerSettingsHistory.reconstruct`, DNI-470 AC-7).
///
/// Filled by DNI-470 (1.8) in
/// `lib/data/repositories/firestore_learner_settings_reader.dart`. Additive
/// to the C0 (DNI-524) surface.
library;

import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

/// Watches a profile's current learner settings.
abstract interface class LearnerSettingsReader {
  /// The current settings of [scope]'s profile, live.
  ///
  /// A profile doc that is missing, or whose settings do not decode (no
  /// valid IANA `time_zone`), is an error event — never a device-local or
  /// default fallback — so every lock reader fails closed (AD-36).
  Stream<LearnerSettings> watch(LearnerScope scope);
}
