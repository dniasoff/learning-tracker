/// The reads `LearningCommands` makes before it writes (AD-31, AD-36,
/// AD-50): the target learner's settings history for the capture gate,
/// the complete event log for corrections, the ContentIndex corpus for
/// `unlearn`, and the AD-50 points amount.
///
/// DNI-469 (1.7). Pure port: the production implementation is composed in
/// `learning_command_providers.dart` from the learner-state providers and
/// `FirestorePointsAmountReader` (`lib/data/repositories/`).
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

/// What a learning command reads before it writes.
abstract interface class LearningCommandReads {
  /// The target learner's settings history (AD-37), which the capture gate
  /// judges `nowUtc` against. Throws when it cannot be read; the command
  /// then fails closed and writes nothing (AD-36, FR-23).
  Future<LearnerSettingsHistory> settingsHistory(LearnerScope scope);

  /// The complete `learning_events` log of [scope] (corrections only;
  /// capture never reads it).
  Future<List<LearningEvent>> events(LearnerScope scope);

  /// The unscoped ContentIndex corpus of [curriculumId], or null when the
  /// curriculum has none.
  Future<Corpus?> corpus(String curriculumId);

  /// The AD-50 amount of a `pts_{eventId}` entry:
  /// `point_configs[curriculumId, stage ?? firstStageOrder]`.
  Future<int> pointsAmount(LearnerScope scope, String curriculumId, int? stage);
}

/// Resolves the AD-50 points amount (`point_configs[curriculum, stage ??
/// firstStageOrder]`, else the default stage ladder).
abstract interface class PointsAmountReader {
  /// The amount for one earning event of [curriculumId] at [stage] (null:
  /// the curriculum's first stage).
  Future<int> pointsAmount(LearnerScope scope, String curriculumId, int? stage);
}

/// A [LearningCommandReads] assembled from one function per read.
final class LearningCommandReadsFrom implements LearningCommandReads {
  /// Creates the reads.
  const LearningCommandReadsFrom({
    required Future<LearnerSettingsHistory> Function(LearnerScope scope)
    settingsHistory,
    required Future<List<LearningEvent>> Function(LearnerScope scope) events,
    required Future<Corpus?> Function(String curriculumId) corpus,
    required PointsAmountReader points,
  }) : _settingsHistory = settingsHistory,
       _events = events,
       _corpus = corpus,
       _points = points;

  final Future<LearnerSettingsHistory> Function(LearnerScope) _settingsHistory;
  final Future<List<LearningEvent>> Function(LearnerScope) _events;
  final Future<Corpus?> Function(String) _corpus;
  final PointsAmountReader _points;

  @override
  Future<LearnerSettingsHistory> settingsHistory(LearnerScope scope) =>
      _settingsHistory(scope);

  @override
  Future<List<LearningEvent>> events(LearnerScope scope) => _events(scope);

  @override
  Future<Corpus?> corpus(String curriculumId) => _corpus(curriculumId);

  @override
  Future<int> pointsAmount(
    LearnerScope scope,
    String curriculumId,
    int? stage,
  ) => _points.pointsAmount(scope, curriculumId, stage);
}
