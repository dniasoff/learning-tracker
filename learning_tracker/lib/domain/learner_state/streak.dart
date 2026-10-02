/// AD-40 streak day: the civil day a learning event counts for.
library;

import 'package:learning_tracker/domain/learner_state/c0_stub.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';

/// The civil day [e] counts for in the streak, or null when it counts for
/// none (AD-40; reads `effectiveAt`).
///
/// C0 stub, filled by DNI-466 (1.4).
CivilDate? streakDay(
  LearningEvent e, {
  required LearnerSettingsHistory settingsHistory,
  required List<LockWindow> locks,
}) => c0Stub('DNI-466', 'streakDay');
