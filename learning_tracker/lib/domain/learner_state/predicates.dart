/// AD-34 sub-track predicates, evaluated on a civil day.
library;

import 'package:learning_tracker/domain/learner_state/c0_stub.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// Whether [s] holds its ground (keeps it off the main track) on [today].
///
/// C0 stub, filled by DNI-467 (1.5).
bool holdsGround(SubTrack s, CivilDate today) =>
    c0Stub('DNI-467', 'holdsGround');

/// Whether [s] shows on the home screen on [today].
///
/// C0 stub, filled by DNI-467 (1.5).
bool onHome(SubTrack s, CivilDate today) => c0Stub('DNI-467', 'onHome');

/// Whether [s] counts in the main-track forecast on [today], given the
/// curriculum [deadline].
///
/// C0 stub, filled by DNI-467 (1.5).
bool inForecast(SubTrack s, CivilDate today, {required CivilDate? deadline}) =>
    c0Stub('DNI-467', 'inForecast');
