/// Port for the governed intent the engine reads: learner settings,
/// main-track intent and goals (AD-35 inputs, AD-37, AD-38, AD-39).
///
/// Filled by DNI-470 (1.8) in `lib/data/repositories/`.
library;

import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

/// The governed intent of one learner, read completely.
final class LearnerIntent {
  /// Creates the intent.
  LearnerIntent({
    required this.settings,
    required Map<String, MainTrackIntent> mainTracks,
    required Map<String, CurriculumGoals> goals,
  }) : mainTracks = Map.unmodifiable(mainTracks),
       goals = Map.unmodifiable(goals);

  /// The current learner settings.
  final LearnerSettings settings;

  /// Main-track intent by curriculum id.
  final Map<String, MainTrackIntent> mainTracks;

  /// Goals by curriculum id.
  final Map<String, CurriculumGoals> goals;

  @override
  String toString() =>
      'LearnerIntent(${mainTracks.length} main tracks, '
      '${goals.length} goals)';
}

/// Reads a learner's governed intent.
abstract interface class GovernedIntentRepository {
  /// The intent of [scope], live.
  ///
  /// Emits only once every intent collection has been read completely, so
  /// no emission yet means loading.
  Stream<LearnerIntent> watch(LearnerScope scope);
}
